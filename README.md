MAT_SEIR_LSTM —Epidemiological Modelling in MATLAB
A Physics-Informed Neural Network (PINN) combined with Long Short-Term Memory (LSTM) networks for SEIR-based epidemiological parameter estimation, incorporating meteorological and epidemiological covariates. Developed and tested in MATLAB R2025b.
1. Getting Started
1.	Download MAT_SEIR_LSTM.zip from the Releases page.
2.	Extract the archive. Keep all files in the same folder — scripts use relative paths and will fail if files are separated.
3.	Open MATLAB, set the working directory to the extracted folder, and follow the instructions below.
2. File Descriptions
SEIR_LSTM_SHS_F30.m — Main modelling script.
param_tune_0406.m — Hyperparameter tuning/optimization script.
Fig_Table_generation.m — Figure and table generation script.
Epidemic and meteorological data_Nepal.xlsx — Input data file used in MATLAB.
v29_figs_lean.mat — Pre-computed results file (MATLAB v7.3).
3. Generating Figures and Tables
To reproduce all figures and tables from the pre-computed results, run Fig_Table_generation.m in MATLAB.
Requires v29_figs_lean.mat in the same folder. No model training is performed — figures are generated directly from saved results and complete in a few minutes.
4. Full Model Run
To run the complete SEIR-LSTM training pipeline from scratch, run SEIR_LSTM_SHS_F30.m in MATLAB.
Requires Epidemic and meteorological data_Nepal.xlsx in the same folder.
Note: Full training is computationally intensive (In 11th gen/i7/16 GB CPU, it took more than 30 hours). Expected runtime varies significantly with hardware. Runtime can be reduced if the MATLAB Parallel Computing Toolbox with a CUDA-capable GPU is available.
5. Hyperparameter Tuning
Lag order, smoothing window length, and LSTM architecture parameters are data-dependent and should be optimized before applying the model to a new dataset.
To run the tuning procedure, run param_tune_0406.m in MATLAB.
Requires Epidemic and meteorological data_Nepal.xlsx in the same folder. Tuning evaluates a large number of parameter combinations and may also take several hours.
6. Data Description (extract SEIR_LSTM_DATA.zip)
1. Compiled Dataset (Epidemic and meteorological data_Nepal.xlsx)
This is the final dataset used in MATLAB. It was compiled by integrating time-varying population data, COVID-19 epidemiological records from multiple surveillance sources, and averaged meteorological data derived from 54 locations across Nepal.  
Source: compiled from 2,3, and 4 (below)
The remaining data files document the compilation process and intermediate sources:
2. population data of nepal.xlsx — time-varying population data used in the compilation of the main dataset.
Source: Nepal Census 2021 (documented within the respective file)
3. covid_19_data_references_JHU_WHO_OWID_Worldometer.xlsx — epidemiological data collected from multiple surveillance platforms and transferred to the main dataset.
Sources: 
Meteorological data_NASApower.zip — raw meteorological data for 54 locations in Nepal. Station-level records were spatially averaged and transferred to the main dataset.
Sources:  NASA POWER Data Access Viewer — https://power.larc.nasa.gov/data-access-viewer 

7. Requirements
MATLAB Version: MATLAB R2025b is recommended. The code was developed and tested on this version. Backward compatibility with R2023b and later is expected but not guaranteed, particularly for dlarray and lstmLayer API calls.
Required MATLAB Toolboxes: Deep Learning Toolbox, Statistics and Machine Learning Toolbox
Optimization Toolbox, Parallel Computing Toolbox (optional but recommended)
Note: To check installed toolboxes, run ver in the MATLAB Command Window.
8. Feature
This repository is designed to support teachers, students, researchers, journal editors, and reviewers working on epidemiological modeling and data-driven analysis.
How to Use
1.	The repository is public.
2.	You can access it directly via URL: https://github.com/shivacaus/SHS-DATA-and-CODE-Resources.
9. License
This repository is publicly available for academic and research purposes. Users may use, reproduce, or adapt the materials with proper citation of the author and repository. Commercial use or redistribution without permission is not allowed.
10. Citation
Subedi, S.H. (2025). SHS-DATA-and-CODE-Resources. SEIR Model-Informed LSTM Framework for Analyzing COVID-19 Dynamics under Meteorological Features. GitHub Repository. https://github.com/shivacaus/SHS-DATA-and-CODE-Resources

11. Contact
For questions or issues, please open a GitHub Issue or contact the corresponding author at [shivacaus1@gmail.com].

