# Godot FFT Ocean Simulation

[mrow1.webm](https://github.com/user-attachments/assets/12452654-ef7e-4010-914a-f3257311f9d6)

FFT-based ocean wave simulation in Godot 4.3 (Forward+). This project was made for a math assignment and was originally inspired by [2Retr0/GodotOceanWaves](https://github.com/2Retr0/GodotOceanWaves) and [Tessendorf's Paper on Simulating Ocean Water](https://jtessen.people.clemson.edu/reports/papers_files/coursenotes2004.pdf).

---

This project generating realistic looking ocean waves by working in the frequency domain (wave spectrum), then converting that into the spatial domain using an inverse Fast Fourier Transform (IFFT) on the GPU.

The paper I wrote on this: [Modelling Realistic Ocean Waves Using Trigonometry.pdf](https://github.com/sebashtioon/Godot-FFT-Ocean-Simulation/blob/main/Modelling%20Realistic%20Ocean%20Waves%20Using%20Trigonometry.pdf)

## how to run it
1. Install [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/)
2. Clone/download this repo
3. Open it in Godot
4. Run the main scene (`main.tscn`)

## implemented features

This project implements a complete ocean simulation/rendering pipeline on the GPU. A physically-motivated wave spectrum is generated in the frequency domain (JONSWAP/TMA-style with directional spreading), distributing wave energy across wave vectors $\mathbf{k}=(k_x,k_y)$ and directions. Each Fourier component is then evolved over time by applying a complex phase rotation,

$$
\tilde{h}(\mathbf{k}, t) = \tilde{h}(\mathbf{k}, 0)\,e^{i\,\omega(\mathbf{k})t}
$$

where the angular frequency $\omega(\mathbf{k})$ follows a dispersion relation. A common finite-depth model is

$$
\omega^2 = gk\,\tanh(kd)
$$

with $k=\|\mathbf{k}\|$, gravity $g$, and water depth $d$

To obtain the actual ocean surface in the spatial domain, an inverse FFT is performed on the GPU (using a Stockham FFT compute kernel), reconstructing the height/displacement field $h(\mathbf{x},t)$:

$$
h(\mathbf{x}, t)=\sum_{\mathbf{k}} \tilde{h}(\mathbf{k}, t)\,e^{i\,\mathbf{k}\cdot\mathbf{x}}
$$

The output is used to generate displacement maps (surface geometry) and normal maps (lighting). Multiple wave cascades are blended across different tile sizes so that large swells and small-scale detail can coexist. On top of that, I added foam/whitecap controls (based on tunable thresholds/parameters) and an optional sea spray effect.


## implementation in godot

[mrow2.webm](https://github.com/user-attachments/assets/ae0e4b83-a407-43a9-83b2-cfe4a8cff19e)


# references

- 2Retr0. “GitHub - 2Retr0/GodotOceanWaves: FFT-Based Ocean-Wave Rendering, Implemented in Godot.” *GitHub*, 2025, github.com/2Retr0/GodotOceanWaves. Accessed 10 May 2025.
  
- Tessendorf, Jerry. *Simulating Ocean Water*.

- 3Blue1Brown. “But What Is the Fourier Transform? A Visual Introduction.” *YouTube*, 26 Jan. 2018, www.youtube.com/watch?v=spUNpyF58BY.

- Acerola. “I Tried Simulating the Entire Ocean.” *YouTube*, 31 Aug. 2023, www.youtube.com/watch?v=yPfagLeUa7k.

- “Category: Linear Water-Wave Theory - WikiWaves.” *Wikiwaves.org*, 2026, www.wikiwaves.org/index.php/Category:Linear_Water-Wave_Theory. Accessed 24 May 2026.

- “Fourtran.dvi.” *EE102: Signal Processing and Linear Systems I: Fourier Transform*, 2001, web.stanford.edu/class/ee102/lectures/fourtran.

- Gauss and the History of The Fast Fourier Transform, https://www.cis.rit.edu/class/simg716/Gauss_History_FFT.pdf

- Horvath, Christopher. *Empirical Directional Wave Spectra for Computer Graphics*. 8 Aug. 2015, https://doi.org/10.1145/2791261.2791267. Accessed 15 Oct. 2023.

- Jump Trajectory. “Ocean Waves Simulation with Fast Fourier Transform.” *YouTube*, 6 Dec. 2020, www.youtube.com/watch?v=kGEqaX4Y4bQ. Accessed 24 May 2026.

- Matusiak, Robert. *Application Report: Implementing Fast Fourier Transform Algorithms of Real-Valued Sequences with the TMS320 DSP Platform*. 2001.

- Mihelich, Mark, and Tim Tcheblokov. *WAKES, EXPLOSIONS and LIGHTING: INTERACTIVE WATER SIMULATION in “ATLAS”*. Mark Mihelich (Grapeshot Games); Tim Tcheblokov (NVIDIA).

- Overleaf, the Online LaTeX Editor. “Learn LaTeX in 30 Minutes - Overleaf, Online LaTeX Editor.” *Overleaf.com*, 2014, www.overleaf.com/learn/latex/Learn_LaTeX_in_30_minutes.

- “Periodic Function.” *Wikipedia*, 21 Aug. 2020, en.wikipedia.org/wiki/Periodic_function.

- Premoze, Simon, and Michael Ashikhmin. “Rendering Natural Waters.” *Computer Graphics Forum*, vol. 20, no. 4, Dec. 2001, pp. 189–199, https://doi.org/10.1111/1467-8659.00548.

- Sims, Karl. “Interactive FFT Tutorial by Karl Sims.” *Karlsims.com*, 2019, www.karlsims.com/fft.html.

- “Sinusoids.” *Stanford.edu*, 2024, ccrma.stanford.edu/~jos/st/Sinusoids.html.

- Swanson, Jez. “An Interactive Introduction to Fourier Transforms.” *Www.jezzamon.com*, www.jezzamon.com/fourier/.

- Tessendorf, Jerry, et al. *Normal Maps for Rendering Vast Ocean Scenes*. 2023.

- “Trochoidal Wave.” *Wikipedia*, 16 Apr. 2020, en.wikipedia.org/wiki/Trochoidal_wave.

- vandyblogger. “Hearing with the Fourier Transform.” *Understanding Ecstasy*, 26 Dec. 2010, understandingecstasy.wordpress.com/2010/12/26/hearing-with-the-fourier-transform/. Accessed 24 May 2026.

- Wikipedia Contributors. “Discrete Fourier Transform.” *Wikipedia*, Wikimedia Foundation, 8 Jan. 2019, en.wikipedia.org/wiki/Discrete_Fourier_transform.

- Wikipedia Contributors. “Fast Fourier Transform.” *Wikipedia*, Wikimedia Foundation, 17 Aug. 2019, en.wikipedia.org/wiki/Fast_Fourier_transform.

- Wikipedia Contributors. “Fourier Transform.” *Wikipedia*, Wikimedia Foundation, 11 July 2019, en.wikipedia.org/wiki/Fourier_transform.

- Wikipedia Contributors. “Sine Wave.” *Wikipedia*, Wikimedia Foundation, 23 Apr. 2019, en.wikipedia.org/wiki/Sine_wave.

- “WikiWaves.” *Wikiwaves.org*, 2025, www.wikiwaves.org/index.php/Main_Page.
