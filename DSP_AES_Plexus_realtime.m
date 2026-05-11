%% DSP_AES_Plexus_stable_int16.m
% Stable AES + Plexus realtime demo using int16 PCM as canonical format
clear; clc; close all;

%% Parameters
recordDuration = 5;        % seconds
fs = 16000;                % sampling rate (match your mic)
aesKey = 'abcdefghijklmnop';   % 16-byte AES key
plexusIterations = 3;

fprintf('\n🎙️ Recording %d seconds of audio (fs=%d)...\n', recordDuration, fs);
recObj = audiorecorder(fs, 16, 1);
recordblocking(recObj, recordDuration);
x = getaudiodata(recObj);           % double in [-1,1]
x = x(:);
if max(abs(x))>0, x = x / max(abs(x)); end
N = numel(x);
fprintf('Samples captured: %d\n', N);

%% Convert to int16 PCM bytes (canonical)
pcm = int16(round(x * 32767));      % int16 PCM
audioBytes = typecast(pcm, 'uint8');% little-endian uint8 array
origAudioBytes = audioBytes;        % keep for comparison

% Ensure multiple of 16 bytes (AES blocksize)
pad = mod(16 - mod(numel(audioBytes), 16), 16);
if pad > 0
    audioBytes = [audioBytes; zeros(pad,1,'uint8')];
end
fprintf('Byte length (padded): %d (pad=%d)\n', numel(audioBytes), pad);

%% AES encrypt (blockwise via Java cipher)
try
    encBytes = aes_process_java(audioBytes, aesKey, 'enc');
catch ME
    error('AES encrypt failed: %s', ME.message);
end

%% Plexus permutation
perm = compute_plexus_permutation(numel(encBytes), plexusIterations);
encPerm = encBytes(perm);

%% Inverse permutation and decryption
invPerm = zeros(size(perm)); invPerm(perm) = 1:numel(perm);
recoveredPerm = encPerm(invPerm);

try
    decBytes = aes_process_java(recoveredPerm, aesKey, 'dec');
catch ME
    error('AES decrypt failed: %s', ME.message);
end

% Remove padding bytes if any
if pad>0
    decBytes = decBytes(1:end-pad);
end

%% Compare bytes (original PCM bytes vs decrypted)
matchCount = sum(origAudioBytes == decBytes(1:numel(origAudioBytes)));
matchRatio = matchCount / numel(origAudioBytes) * 100;
fprintf('Byte match ratio: %.4f %% (%d / %d bytes)\n', matchRatio, matchCount, numel(origAudioBytes));

% If not exact match, show first few differing bytes for debugging
if matchRatio < 99.9
    idxDiff = find(origAudioBytes ~= decBytes(1:numel(origAudioBytes)));
    fprintf('First differing byte indices (up to 20):\n');
    disp(idxDiff(1:min(20,numel(idxDiff)))');
    fprintf('Original bytes (first 16): '); disp(origAudioBytes(1:16)');
    fprintf('Decrypted bytes(first 16): '); disp(decBytes(1:16)');
end

%% Reconstruct int16 PCM -> audio samples
try
    pcm_rec = typecast(uint8(decBytes(1:numel(origAudioBytes))), 'int16');
catch
    error('Reconverting bytes to int16 failed. Byte count mismatch.');
end

% Ensure length matches original PCM length
pcm_rec = pcm_rec(1:numel(pcm));
y = double(pcm_rec) / 32767;
if max(abs(y))>0, y = y / max(abs(y)); end

%% Play: Original, Encrypted preview, Recovered
disp('Playing ORIGINAL'); sound(double(pcm)/32767, fs); pause(recordDuration + 0.5);

% Encrypted preview: take same number of bytes as original PCM, scale to [-1,1]
% --- Encrypted preview: truncated to same number of samples as original ---
encPreviewBytes = encPerm(1:min(numel(encPerm), numel(origAudioBytes)));

% Convert to rough audio waveform in [-1,1]
encPreview = (double(encPreviewBytes) - 128) / 128;
encPreview = encPreview(:);

% Match exact playback duration
playSamples = min(length(encPreview), length(pcm));
encPreview = encPreview(1:playSamples);

disp('Playing ENCRYPTED (preview)...');
sound(encPreview, fs);
pause(recordDuration + 0.5);

disp('Playing RECOVERED'); sound(y, fs); pause(recordDuration + 0.5);

%% Compute metrics if bytes match reasonably
%% Compute metrics if bytes match reasonably
if matchRatio > 99
    err = double(pcm)/32767 - y;
    mseVal = mean(err.^2);
    if mseVal < 1e-12
        mseVal = 0; % treat as perfect match
    end

    if mseVal == 0
        snrVal = Inf;
        psnrVal = Inf;
        corrVal = 1.0;
        fprintf('\n✅ Perfect reconstruction detected — zero error.\n');
    else
        snrVal = 10*log10(sum((double(pcm)/32767).^2)/sum(err.^2));
        psnrVal = 10*log10(1 / mseVal);
        corrVal = corr2(double(pcm)/32767, y);
    end
else
    mseVal = NaN; snrVal = NaN; psnrVal = NaN; corrVal = NaN;
    warning('Low byte match ratio — metrics will be NaN to avoid misleading values.');
end

fprintf('\nMetrics:\n  MSE=%.6g\n  SNR=%s\n  PSNR=%s\n  Corr=%.6f\n', ...
    mseVal, num2str(snrVal), num2str(psnrVal), corrVal);


%% Visualizations: time, spectrum, spectrogram
nfft = 2^nextpow2(N);
f = (0:nfft-1)*(fs/nfft);
origSignal = double(pcm)/32767;
E = abs(fft(encPreview .* hann(length(encPreview)), nfft));
X = abs(fft(origSignal .* hann(N), nfft));
Y = abs(fft(y .* hann(N), nfft));

figure('Position',[100 100 1400 900]);
subplot(3,3,1); plot((0:N-1)/fs, origSignal); title('Original (time)'); xlim([0 min(0.05, N/fs)]);
subplot(3,3,2); plot((0:length(encPreview)-1)/fs, encPreview); title('Encrypted preview (time)');
subplot(3,3,3); plot((0:N-1)/fs, y); title('Recovered (time)'); xlim([0 min(0.05, N/fs)]);

subplot(3,3,4); plot(f(1:nfft/2),20*log10(X(1:nfft/2)+eps)); title('Original spectrum');
subplot(3,3,5); plot(f(1:nfft/2),20*log10(E(1:nfft/2)+eps)); title('Encrypted spectrum');
subplot(3,3,6); plot(f(1:nfft/2),20*log10(Y(1:nfft/2)+eps)); title('Recovered spectrum');

subplot(3,3,7); spectrogram(origSignal,256,200,256,fs,'yaxis'); title('Orig spectrogram');
subplot(3,3,8); spectrogram(encPreview,256,200,256,fs,'yaxis'); title('Enc spectrogram');
subplot(3,3,9); spectrogram(y,256,200,256,fs,'yaxis'); title('Rec spectrogram');

sgtitle(sprintf('AES+Plexus | match=%.3f%% | SNR=%.2f dB | Corr=%.4f', matchRatio, snrVal, corrVal));
drawnow;

%% ------- Helper: AES via Java with correct unsigned handling -------
function out = aes_process_java(dataBytes_uint8, keyStr, mode)
    import javax.crypto.Cipher
    import javax.crypto.spec.SecretKeySpec

    % Ensure uint8 array
    if ~isa(dataBytes_uint8,'uint8')
        dataBytes_uint8 = uint8(dataBytes_uint8);
    end

    % Convert unsigned uint8 -> signed int8 for Java
    inInt8 = int8(double(dataBytes_uint8) - 128); % map 0..255 -> -128..127

    % Create Java byte[] from MATLAB int8 vector
    % Use typecast to obtain a MATLAB int8 array and then call doFinal on it.
    cipher = Cipher.getInstance('AES/ECB/NoPadding');
    key = uint8(keyStr(:));
    sk = SecretKeySpec(int8(key(:)), 'AES');

    if strcmpi(mode,'enc')
        cipher.init(Cipher.ENCRYPT_MODE, sk);
    else
        cipher.init(Cipher.DECRYPT_MODE, sk);
    end

    % Call Java cipher
    outJava = cipher.doFinal(inInt8);  % returns int8-like Java array in MATLAB

    % Convert returned Java bytes (signed) to MATLAB uint8: map -128..127 -> 0..255
    out = uint8(double(outJava) + 128);
end

%% ------- Helper: Plexus permutation -------
function perm = compute_plexus_permutation(L, iterations)
    perm = (1:L).';
    for it = 1:iterations
        rng(it);                 % deterministic per iteration
        perm = perm(randperm(L));
    end
end