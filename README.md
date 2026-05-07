**MAT_SEIR_LSTM — Epidemiological Modelling in MATLAB**

Code and Data for the manuscript: 

SEIR Model-Informed LSTM Framework for Analyzing COVID-19 Dynamics under Meteorological Features.
A Physics-Informed Neural Network (PINN) combined with Long Short-Term Memory (LSTM) networks for SEIR-based epidemiological parameter estimation, incorporating meteorological and epidemiological covariates.

Developed and tested in MATLAB R2025b.

This branch contains 3 files: 

i) MAT_SEIR_LSTM.zip, 

ii) SEIR_LSTM_DATA.zip, and 

iii) README.md (this file).

**Working with MAT_SEIR_LSTM.zip**

1. Download MAT_SEIR_LSTM.zip from this branch.
   
2. Extract the archive. Keep all files in the same folder — scripts use relative paths and will fail if files are separated.
   
3. Open MATLAB, set the working directory to the extracted folder, and follow the instructions below.
   
4. File Descriptions:
   
i) SEIR_LSTM_SHS_F30.m — Main modelling script.

ii) param_tune_0406.m — Hyperparameter tuning/optimization script.

iii) F30_fig_table_generation.m — Figure and table generation script.

iv) Epidemic and meteorological data_Nepal.xlsx — Input data file used in MATLAB.

v) F30_fig_table_data.mat — Pre-computed outputs file (MATLAB v7.3).

5. Generating Figures and Tables

To reproduce all figures and tables from the pre-computed results, run F30_fig_table_generation.m in MATLAB.
Requires F30_fig_table_data.mat in the same folder. No model training is performed — figures are generated directly from saved results and complete in seconds.

6. Full Model Run

To run the complete SEIR-LSTM training pipeline from scratch, run SEIR_LSTM_SHS_F30.m in MATLAB.
Requires Epidemic and meteorological data_Nepal.xlsx in the same folder.

Note: Full training is computationally intensive. On an 11th Gen Intel Core i7 with 16 GB RAM, runtime exceeded 30 hours. Expected runtime varies significantly with hardware. Runtime can be reduced if the MATLAB Parallel Computing Toolbox with a CUDA-capable GPU is available.

7. Hyperparameter Tuning/Optimization

Lag order, smoothing window length, and LSTM architecture parameters are data-dependent and should be optimized before applying the model to a new dataset.
To run the tuning procedure, run param_tune_0406.m in MATLAB.
Requires Epidemic and meteorological data_Nepal.xlsx in the same folder. Tuning evaluates a large number of parameter combinations and may also take several hours.

8. Requirements 

i) MATLAB Version: MATLAB R2025b is recommended. The code was developed and tested on this version. Backward compatibility with R2023b and later is expected but not guaranteed, particularly for dlarray and lstmLayer API calls.

ii) Required MATLAB Toolboxes:
- Deep Learning Toolbox
- Statistics and Machine Learning Toolbox
- Optimization Toolbox
- Parallel Computing Toolbox (optional but recommended)

Note: To check installed toolboxes, run ver in the MATLAB Command Window.


**Working with SEIR_LSTM_DATA.zip**

9. Extract SEIR_LSTM_DATA.zip. It contains 4 files.

i)  Epidemic and meteorological data_Nepal.xlsx — Compiled Dataset (from 2020-05-08 to 2022-12-31)

This is the final dataset used in MATLAB. It was compiled by integrating time-varying population data, COVID-19 epidemiological records from multiple surveillance sources, and averaged meteorological data derived from 54 locations across Nepal.

Source: compiled from files 2, 3, and 4 below.

The remaining files document the compilation process and intermediate sources:

ii)  population data of nepal.xlsx — time-varying population data used in the compilation of the main dataset.

Sources:

* https://population.un.org/dataportal/data/indicators/55,59,65,49/locations/524/start/2020/end/2022/table/pivotbylocation?df=69f1e08c-f85b-4a89-aa35-8ff1f863f478 accessed: 2024-05-02

* https://www.macrotrends.net/global-metrics/countries/npl/nepal/net-migration (accessed: 2024-04-10)

* https://censusnepal.cbs.gov.np/Home/Index/EN, (accessed: 2024-04-10)

iii)  covid_19_data_references_JHU_WHO_OWID_Worldometer.xlsx — epidemiological data collected from multiple surveillance platforms and transferred to the main dataset.

Sources:

* World Health Organisation (WHO-Nepal): https://data.who.int/dashboards/covid19/data (accessed: 2023-02-26, filtered for Nepal)
  
* Our World in Data (OWID): https://github.com/owid/covid-19-data/blob/master/public/data/owid-covid-data.csv (accessed: 2023-02-20, filtered for Nepal)
  
* Worldometer: https://www.worldometers.info/coronavirus/country/nepal/ (accessed: 2023-02-26, Right Click >> View Page Source)
  
* Johns Hopkins University (JHU): https://github.com/CSSEGISandData/COVID-19/tree/246b73fd28ebab168a764380a5cb62cb375c298d/csse_covid_19_data/csse_covid_19_time_series    (accessed: 2023-02-15, filtered for Nepal)
  
* COVID-19 Dashboard, Ministry of Health and Population, Nepal: https://covid19.mohp.gov.np/ (Accessed: 2023-02-25)

iv)  Meteorological data_NASApower.zip — raw meteorological data for 54 locations in Nepal. Station-level records were spatially averaged and transferred to the main dataset.

Source: NASA POWER Data Access Viewer — https://power.larc.nasa.gov/data-access-viewer, (accessed: 2023-04-12)

9. Features

This repository is designed to support teachers, students, researchers, journal editors, and reviewers working on epidemiological modelling and data-driven analysis.
The repository is public and can be accessed directly via:

https://github.com/shivacaus/SHS-DATA-and-CODE-Resources/tree/Data-and-code-for-Journal

9. License

This repository is publicly available for academic and research purposes. The code is licensed under the MIT License. The data is licensed under Creative Commons Attribution 4.0 International (CC BY 4.0). Users may use, reproduce, or adapt the materials with proper citation of the author and repository. Commercial use or redistribution for commercial purposes is not permitted.

10. Citation

Subedi, S.H. (2026). MAT_SEIR_LSTM — SEIR Model-Informed LSTM Framework for Analyzing COVID-19 Dynamics under Meteorological Features. Zenodo. https://doi.org/10.5281/zenodo.19709234.

11. Contact

For questions or issues, please open a GitHub Issue or contact the corresponding author at shivacaus1@gmail.com.
