# Audio Plexus Encryption using AES Algorithm - MATLAB

## Description
Real-time audio encryption and decryption using AES-128 (ECB mode)
combined with Plexus permutation in MATLAB.

## Features
- Records live audio and encrypts using AES + Plexus permutation
- Processes audio datasets with batch encryption/decryption
- Visualizes original, encrypted, and recovered waveforms and spectra
- Perfect reconstruction verified (100% byte match, Corr=1.0)

## Files
- DSP_AES_Plexus_realtime.m → Live microphone recording + encryption
- DSP_AES_Plexus_dataset.m  → Batch processing of audio dataset

## Results
| File | PSNR (dB) | Correlation |
|------|-----------|-------------|
| FSDD_0_george_0  | 185.14 | 1.000000 |
| FSDD_0_george_1  | 187.28 | 1.000000 |
| FSDD_0_george_10 | 187.10 | 1.000000 |
| FSDD_0_george_11 | 188.74 | 1.000000 |
| FSDD_0_george_12 | 188.26 | 1.000000 |

## Requirements
- MATLAB with Java enabled
- Audio Toolbox
- 16-byte AES key

## Algorithm
1. Record/load audio → convert to int16 PCM bytes
2. Encrypt blockwise using AES-128 ECB via Java Cipher
3. Apply Plexus permutation (3 iterations)
4. Reverse permutation + AES decrypt to recover original