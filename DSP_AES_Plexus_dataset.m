
% 40% milestone: AES + Plexus encryption, with audible encrypted & recovered audio
clear; clc; close all;

%% -------- Parameters --------
datasetsMat = fullfile('..','datasets','audioDataAll.mat');
if ~exist(datasetsMat,'file'), datasetsMat = fullfile('datasets','audioDataAll.mat'); end
if ~exist(datasetsMat,'file'), error('datasets/audioDataAll.mat not found. Run loader first.'); end

aesKey = 'abcdefghijklmnop'; % 16-char AES-128 key
plexusIterations = 3;        % number of permutation iterations

resultsFolder = fullfile('results');
if ~exist(resultsFolder,'dir'), mkdir(resultsFolder); end
encFolder = fullfile(resultsFolder, 'encrypted');
recFolder = fullfile(resultsFolder, 'recovered');
figsFolder = fullfile(resultsFolder, 'figs');
if ~exist(encFolder,'dir'), mkdir(encFolder); end
if ~exist(recFolder,'dir'), mkdir(recFolder); end
if ~exist(figsFolder,'dir'), mkdir(figsFolder); end

%% -------- Load data --------
S = load(datasetsMat,'audioDataAll','labels','targetFs');
audioDataAll = S.audioDataAll; labels = S.labels; fs = S.targetFs;
if isempty(audioDataAll), error('audioDataAll empty'); end

%% -------- Java availability check --------
try
    import javax.crypto.Cipher
catch
    error('Java Cipher not available in this MATLAB. Enable Java.');
end

%% -------- AES-only sanity test --------
fprintf('Running AES-only round-trip test...\n');
dummy = uint8(0:63).';
enc = aes_blocks(dummy, aesKey, 'enc');
dec = aes_blocks(enc, aesKey, 'dec');
assert(isequal(dummy, dec), 'AES-only round-trip failed.');
fprintf('AES-only test: PASS\n');

%% -------- Process first 5 files --------
nFiles = min(5, numel(audioDataAll));
for k = 1:nFiles
    fprintf('\n[%d/%d] Processing: %s\n', k, nFiles, labels{k});
    x = audioDataAll{k};
    x = double(x);
    if max(abs(x))>1, x = x / max(abs(x)); end

    % Convert to bytes
    audioBytes = typecast(single(x),'uint8');
    padLen = mod(16 - mod(numel(audioBytes),16), 16);
    if padLen>0, audioBytes = [audioBytes; zeros(padLen,1,'uint8')]; end

    % Encrypt with AES
    encBytes = aes_blocks(audioBytes, aesKey, 'enc');

    % Apply Plexus permutation
    permA = compute_plexus_permutation(numel(encBytes), plexusIterations);
    encPermA = encBytes(permA);

    % Save encrypted bytes
    encFile = fullfile(encFolder, sprintf('encrypted_%s.bin', labels{k}));
    fid = fopen(encFile,'w');
    fwrite(fid, encPermA, 'uint8');
    fclose(fid);

    % --- Convert encrypted bytes to audio & play ---
    encFloat = double(encPermA);
    encFloat = (encFloat - 128) / 128;   % Map to [-1, 1]
    encFloat = encFloat(:);
    playLen = min(numel(encFloat), fs*5);

    % --- Inverse permutation & AES decryption ---
    invPermA = zeros(size(permA)); invPermA(permA) = 1:numel(permA);
    recoveredEncBytes = encPermA(invPermA);
    decBytes = aes_blocks(recoveredEncBytes, aesKey, 'dec');
    if padLen>0, decBytes = decBytes(1:end-padLen); end

    % Bytes -> audio
    y = typecast(decBytes,'single');
    y = double(y);

    % Match lengths
    if numel(y) > numel(x)
        y = y(1:numel(x));
    elseif numel(y) < numel(x)
        y = [y; zeros(numel(x)-numel(y),1)];
    end
    if max(abs(y))>1, y = y / max(abs(y)); end

    % --- Save comparison figure ---
    try
        save_comparison_fig(x, encFloat, y, fs, labels{k}, figsFolder);

    catch ME
        warning('Could not save comparison figure for %s: %s', labels{k}, ME.message);
    end

    % --- Save encrypted and recovered audio files ---
    encAudioFile = fullfile(encFolder, sprintf('encrypted_%s.wav', labels{k}));
    recFile      = fullfile(recFolder, sprintf('recovered_%s.wav', labels{k}));
    audiowrite(encAudioFile, encFloat, fs);
    audiowrite(recFile, y, fs);

    % --- Metrics ---
    mseVal = mean((x - y).^2);
    psnrVal = Inf; 
    if mseVal>0, psnrVal = 10*log10(1^2/mseVal); end
    corrVal = corr2(x,y);
    fprintf('   PSNR=%.2f dB, Corr=%.6f\n', psnrVal, corrVal);

    % --- Playback sequence ---
    fprintf('   Playing ORIGINAL (2 s)...\n');
    sound(x(1:min(end,fs*2)), fs);
    pause(2.5);

    fprintf('   Playing ENCRYPTED (2 s)...\n');
    sound(encFloat(1:min(end,fs*2)), fs);
    pause(2.5);

    fprintf('   Playing RECOVERED (2 s)...\n');
    sound(y(1:min(end,fs*2)), fs);
    pause(3);

    fprintf('   --- Done with %s ---\n', labels{k});
end

fprintf('\nProcessed %d files. Results in: %s\n', nFiles, resultsFolder);

%% ======= Helper functions =======
function out = aes_blocks(dataBytes, key, mode)
    if mod(numel(dataBytes),16)~=0, error('Length must be multiple of 16'); end
    nBlocks = numel(dataBytes)/16;
    out = zeros(size(dataBytes),'uint8');
    for b=1:nBlocks
        idx = (b-1)*16 + (1:16);
        if strcmp(mode,'enc')
            out(idx) = aes_java_encrypt_block(dataBytes(idx), key);
        else
            out(idx) = aes_java_decrypt_block(dataBytes(idx), key);
        end
    end
end

function out = aes_java_encrypt_block(inBlock, key)
    if ischar(key), key = uint8(key); end
    inBlock = uint8(inBlock(:));
    keyUint8 = uint8(key(:));
    inJava = typecast(inBlock, 'int8');
    keyJava = typecast(keyUint8, 'int8');
    import javax.crypto.Cipher
    import javax.crypto.spec.SecretKeySpec
    cipher = Cipher.getInstance('AES/ECB/NoPadding');
    sk = SecretKeySpec(keyJava, 'AES');
    cipher.init(Cipher.ENCRYPT_MODE, sk);
    outJava = cipher.doFinal(inJava);
    out = typecast(outJava(:), 'uint8');
end

function out = aes_java_decrypt_block(inBlock, key)
    if ischar(key), key = uint8(key); end
    inBlock = uint8(inBlock(:));
    keyUint8 = uint8(key(:));
    inJava = typecast(inBlock, 'int8');
    keyJava = typecast(keyUint8, 'int8');
    import javax.crypto.Cipher
    import javax.crypto.spec.SecretKeySpec
    cipher = Cipher.getInstance('AES/ECB/NoPadding');
    sk = SecretKeySpec(keyJava, 'AES');
    cipher.init(Cipher.DECRYPT_MODE, sk);
    outJava = cipher.doFinal(inJava);
    out = typecast(outJava(:), 'uint8');
end

function out = compute_plexus_permutation(L, iterations)
    perm = (1:L).';
    for it = 1:iterations
        rng(it);
        perm = perm(randperm(L));
    end
    out = perm;
end

function save_comparison_fig(orig, enc, rec, fs, label, outFolder)
    % --- Ensure same length ---
    orig = orig(:);
    enc = enc(:);
    rec = rec(:);
    N = min([length(orig), length(enc), length(rec)]);
    orig = orig(1:N);
    enc  = enc(1:N);
    rec  = rec(1:N);
    t = (0:N-1)/fs;

    % --- Compute FFTs ---
    nfft = 2^nextpow2(N);
    f = (0:nfft-1)*(fs/nfft);
    half = 1:floor(nfft/2);
    SPECo = abs(fft(orig .* hann(N), nfft));
    SPECe = abs(fft(enc  .* hann(N), nfft));
    SPECr = abs(fft(rec  .* hann(N), nfft));

    % --- Create figure ---
    h = figure('Visible','off','Units','pixels','Position',[100 100 1400 800]);

    % ---- Time-domain waveforms ----
    subplot(2,3,1);
    plot(t, orig); title('Original waveform');
    xlabel('Time (s)'); ylabel('Amplitude');
    xlim([0, min(0.05, t(end))]);

    subplot(2,3,2);
    plot(t, enc); title('Encrypted waveform');
    xlabel('Time (s)'); ylabel('Amplitude');
    xlim([0, min(0.05, t(end))]);

    subplot(2,3,3);
    plot(t, rec); title('Recovered waveform');
    xlabel('Time (s)'); ylabel('Amplitude');
    xlim([0, min(0.05, t(end))]);

    % ---- Frequency-domain spectra ----
    subplot(2,3,4);
    plot(f(half), 20*log10(SPECo(half)+eps)); 
    title('Original spectrum'); xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
    xlim([0 fs/2]);

    subplot(2,3,5);
    plot(f(half), 20*log10(SPECe(half)+eps)); 
    title('Encrypted spectrum'); xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
    xlim([0 fs/2]);

    subplot(2,3,6);
    plot(f(half), 20*log10(SPECr(half)+eps)); 
    title('Recovered spectrum'); xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
    xlim([0 fs/2]);

    % ---- Overall title ----
    sgtitle(sprintf('AES + Plexus Encryption | %s', strrep(label,'_','\_')));

    % ---- Save figure ----
    fname = fullfile(outFolder, ['cmp_' matlab.lang.makeValidName(label) '.png']);
    try
        saveas(h, fname);
    catch
        print(h, fname, '-dpng');
    end
    close(h);
end