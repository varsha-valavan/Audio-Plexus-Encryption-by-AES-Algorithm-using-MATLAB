<div align="center">

# 🎧 Audio Plexus
### Real-Time Audio Encryption using AES-128 + Plexus Permutation (MATLAB)

*Your voice, scrambled beyond recognition — and reconstructed without losing a single bit.*

![Language](https://img.shields.io/badge/MATLAB-Audio%20Toolbox-orange?style=flat-square&logo=mathworks)
![Encryption](https://img.shields.io/badge/Encryption-AES--128%20ECB-critical?style=flat-square)
![Fidelity](https://img.shields.io/badge/Reconstruction-100%25%20Lossless-brightgreen?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)

</div>

---

## 💡 Why This Project Exists

Voice data is some of the most personal data we generate — yet most audio pipelines treat it as an afterthought when it comes to security. Standard AES encryption alone can leave exploitable statistical structure in a signal.

**Audio Plexus** layers a custom **Plexus permutation** on top of standard **AES-128** block encryption, scrambling audio at the block level *and* the structural level — then proves, byte-for-byte, that the original signal can be perfectly recovered.

> Record it. Encrypt it. Permute it. Reverse it. Get every single sample back — exactly.

---

## ⚙️ How It Works — At a Glance

```
   ┌───────────────┐        ┌──────────────────┐        ┌───────────────────┐
   │  Live Audio /  │  PCM   │   AES-128 (ECB)    │  Perm  │  Plexus Permutation │
   │  Dataset Input │ ─────► │  Java Cipher Enc.   │ ─────► │   (3 Iterations)     │
   └───────────────┘        └──────────────────┘        └─────────┬─────────┘
                                                                    │
                                                          Encrypted Audio Stream
                                                                    │
                                                                    ▼
                                                        ┌───────────────────────┐
                                                        │  Reverse Permutation +  │
                                                        │    AES-128 Decrypt      │
                                                        └───────────┬────────────┘
                                                                    │
                                                                    ▼
                                                     Recovered Audio (100% Byte Match)
```

---

## ✨ Highlights

| | |
|---|---|
| 🎙️ **Live Recording Mode** | Captures microphone input and encrypts in real time |
| 📦 **Batch Dataset Mode** | Processes entire audio datasets automatically |
| 🔐 **AES-128 + Plexus** | Standard block cipher reinforced with custom permutation layer |
| 🎯 **Perfect Reconstruction** | 100% byte match, correlation = 1.000000 across all tested files |
| 📊 **Full Visualization** | Waveform + spectral comparison: original vs encrypted vs recovered |
| ☕ **Java Cipher Backed** | Uses MATLAB's Java interop for standards-compliant AES |

---

## 🧩 System Architecture

**Encryption Path:**
`Audio Input (Live/Dataset)` → `int16 PCM Bytes` → `AES-128 ECB Encrypt` → `Plexus Permutation (×3)` → `Encrypted Stream`

**Decryption Path:**
`Encrypted Stream` → `Reverse Plexus Permutation` → `AES-128 ECB Decrypt` → `Recovered PCM Bytes` → `Original Audio`

---

## 📊 Reconstruction Fidelity

Every processed file is verified against its original using PSNR and correlation — and every single one comes back **perfect**:

| File | PSNR (dB) | Correlation |
|---|:---:|:---:|
| FSDD_0_george_0  | 185.14 | 1.000000 |
| FSDD_0_george_1  | 187.28 | 1.000000 |
| FSDD_0_george_10 | 187.10 | 1.000000 |
| FSDD_0_george_11 | 188.74 | 1.000000 |
| FSDD_0_george_12 | 188.26 | 1.000000 |

> PSNR values above 180dB indicate reconstruction error at the level of floating-point noise — effectively lossless.

---

## 🛠️ Files in This Repo

| File | Purpose |
|---|---|
| `DSP_AES_Plexus_realtime.m` | Live microphone recording + real-time encryption/decryption |
| `DSP_AES_Plexus_dataset.m` | Batch encryption/decryption across an audio dataset |

---

## 🧮 The Algorithm, Step by Step

1. **Capture** — Record live audio or load a dataset file, convert to `int16` PCM bytes
2. **Encrypt** — Apply AES-128 in ECB mode, blockwise, via MATLAB's Java `Cipher` class
3. **Permute** — Apply the Plexus permutation across 3 iterations to further scramble block structure
4. **Reverse** — Undo the permutation, then AES-decrypt to recover the original signal exactly

---

## 📋 Requirements

- MATLAB with **Java enabled**
- **Audio Toolbox**
- A 16-byte AES key

---

## 🗺️ Roadmap

- [ ] Support for AES-CBC / GCM modes with IV handling
- [ ] Configurable Plexus permutation depth
- [ ] Real-time streaming decryption for playback
- [ ] Key exchange module for secure key sharing

---
## Team Member

Akshaya H 

---

## 📄 License

Released under the **MIT License** — free to use, modify, and build upon.

<div align="center">

*Encrypted in transit. Perfect on arrival.*

</div>
