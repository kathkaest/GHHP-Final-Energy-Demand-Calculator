# GHHP-Final Energy Demand Calculator (v1)

This repository provides and documents an R package which computes the building-level energy performance for households in the German Heating and Housing Panel (GHHP). It estimates final energy demand and reference heating costs for each observation and directly ships with a Shiny app UI to run the full pipeline.

## Abstract Tool

The *Final Energy Demand Calculator* is an R-based tool that extends the GHHP by providing building-level estimates of final energy demand and corresponding reference annual heating costs. Using GHHP data on key building characteristics – such as construction period, past retrofits, and installed heating and hot-water systems – the tool estimates, for each observation:

- Final energy demand for domestic hot water and space heating (kWh/m²a)  
- Their sum as total final energy demand `ebj` (kWh/m²a)  
- Corresponding approximate annual energy costs `kdj` (€/year)  

Final energy demand represents the amount of energy required to **heat a dwelling and supply hot water under standardized conditions**, making it a central indicator of a building’s energy efficiency.

The estimation procedure follows the established *Kurzverfahren Energieprofil* developed by Loga et al. (2005). Default parameter tables – such as envelope U-values, window U/g-values, climate coefficients, system loss and credit factors, and energy-carrier prices – are included in the `02 Parameter/` folder but can be modified by users to test alternative engineering assumptions or price scenarios.

By linking an engineering model with representative survey data, the *Final Energy Demand Calculator* enables a consistent assessment of energy efficiency both at the household level and across the German residential building stock, providing a basis for empirical analysis and policy design in the building sector.

## Data Access

The building data used for the calculation come from the **German Heating and Housing Panel (GHHP)**, established as part of the Kopernikus Ariadne project funded by the Federal Ministry of Education and Research (BMBF).  

Input data from the GHHP are available as **Scientific Use Files (SUFs)** under a **Creative Commons Non-Commercial license**. Access is granted exclusively for scientific, non-commercial research to researchers affiliated with academic institutions and requires a signed data use agreement.

### Available Waves and Required Files

Currently, **Wave 1 (2021)** and **Wave 2 (2022)** are available for scientific use. Each wave consists of two main datasets: **Building Characteristics** and **Socioeconomic Characteristics & Experiments**. For this tool, the required input files are (place in `01 Raw/`):

- `ariadne_panel1_buildingchars_eng_update24.dta`  
- `ariadne_panel1_experiments_eng_update24.dta`  
- `ariadne_panel2_buildingchars_eng.dta`  
- `ariadne_panel2_experiments_eng.dta`  

The GHHP SUFs can be accessed free of charge via the **Research Data Centre Ruhr (FDZ Ruhr) at RWI**:

- GHHP data overview:  
  <https://www.rwi-essen.de/en/research-advice/further/research-data-center-ruhr-fdz/data-sets/microdata/german-heating-and-housing-panel>

- General data access information:  
  <https://www.rwi-essen.de/en/research-advice/further/research-data-center-ruhr-fdz/data-access>

The data access application typically requires:

- A short project description and title  
- Information on the applying institution/department  
- Expected duration of data usage  
- Names of all project participants  

### License and Citation of the GHHP Data

Data are provided under a **Creative Commons Non-Commercial license**. Users must comply with the FDZ Ruhr data-use agreement and **cite the GHHP datasets properly with their respective DOIs**.

For the building characteristics modules used by this tool, the DOIs of the current versions include (examples):

- **Scientific Use File (SUF) Wave 1 2021 – Building Characteristics:**  
  <https://doi.org/10.7807/ghhp:building:v1>

- **Scientific Use File (SUF) Wave 2 2022 – Building Characteristics:**  
  <https://doi.org/10.7807/GHHP:BUILDING:V2>

Please refer to the FDZ Ruhr and GHHP documentation for the most recent DOIs and citation formats for the socioeconomic/experiment files and updated versions.

### Runtime

On a standard 2024 desktop, total runtime for a full wave is well below 10 minutes. In recent tests (6-core Intel i5-8500, Windows 11), the end-to-end computation took approximately **1–2 minutes**.

## More Information

- Repository for V1: [![DOI](https://zenodo.org/badge/1063309544.svg)](https://doi.org/10.5281/zenodo.17791209)   
- If you use this tool, **please also cite the software** (see “Cite this repository” in your code or project metadata / CITATION file).

## Contact Person

For questions about the tool or its use with GHHP data, please contact:  

**[Dr. Kathrin Kaestner](https://www.rwi-essen.de/en/rwi/team/person/kathrin-kaestner)**

## Disclaimer

All rights reserved to **RWI – Leibniz Institute for Economic Research** and the authors of the code:

- [Prof. Dr. Andreas Gerster](https://environmental.economics.uni-mainz.de/team/andreas-gerster/)  
- [Dr. Kathrin Kaestner](https://www.rwi-essen.de/en/rwi/team/person/kathrin-kaestner)  
- [Anton Knoche](https://www.pik-potsdam.de/members/antonkn/homepage)  
- [Martina Milcetic](https://environmental.economics.uni-mainz.de/team-martina-milcetic-phd-candidate/)  
- [Jan Schweers](https://environmental.economics.uni-mainz.de/team/team-jan-schweers-phd-candidate/)

Please note that the **terms and conditions of each R package/library used by this tool apply**.

## Further Tool Instructions

### 1) Requirements

To run the package and Shiny app, ensure the following software is installed:

- **R (4.3.3 or newer recommended)**  
  <https://cran.r-project.org/>

- **Optional but recommended: RStudio Desktop (latest)**  
  <https://posit.co/download/rstudio-desktop/>

- **Internet connection**  
  The app installs any missing R packages from CRAN automatically on first run.

### 2) Folder layout (expected)

Within your project directory, the app expects the following structure (subfolder names should match exactly):

- `01 Raw/`  
  (GHHP SUF `.dta` files obtained via FDZ Ruhr)
  - `ariadne_panel1_buildingchars_eng_update24.dta`
  - `ariadne_panel1_experiments_eng_update24.dta`
  - `ariadne_panel2_buildingchars_eng.dta`
  - `ariadne_panel2_experiments_eng.dta`

- `02 Parameter/`  
  Default engineering and price parameter tables (can be modified/replaced):
  - `Fehlende Werte.xlsx` (imputation rules for survey items)
  - `U Werte Baukonstruktion_update.xlsx`
  - `U und G Werte Fenster_update.xlsx`
  - `Klimakoeffizienten.xlsx`
  - `Kosten pro Energietraeger.xlsx`
  - `Waermekennwerte Anlagentechnik.xlsx`

- `03 R Code/`  
  Core estimation scripts (called from the master script / app):
  - `00_Master_File.R`
  - `01_WuW_Data.R`
  - `02_Individual_Parameters.R`
  - `03_System_Technology.R`
  - `04_Building_Balance_Sheet.R`
  - `05_System_Balance_Sheet.R`

- `04 Intermediate Results/`  
  Created and used by the pipeline for intermediate tables and diagnostics.

- `05 Final Results/`  
  Output folder; contains `Result_File.dta` after a successful run.

- `app.R`  
  Shiny app starter file.

The app attempts to **auto-detect the project root** based on the presence of these folders and `app.R`.

### 3) How to run the Shiny app (in R / RStudio)

1. **Launch the app** (either in the R console or via RStudio):

   source("app.R")

   or

   shiny::runApp(".")

   On the first launch, the app will install any missing CRAN packages automatically.

2. In the **app sidebar**:

   - Verify the **Project root folder** input is set to the directory that directly contains `app.R` and the `01–05` folders.
   - Choose the **Data wave**:
     - *Wave 1*: uses  
       `ariadne_panel1_buildingchars_eng_update24.dta` and  
       `ariadne_panel1_experiments_eng_update24.dta`
     - *Wave 2*: uses  
       `ariadne_panel2_buildingchars_eng.dta` and  
       `ariadne_panel2_experiments_eng.dta`
   - (Optional) Adjust **Parameter files**:  
     The text inputs accept **relative paths** (e.g. `02 Parameter/U Werte Baukonstruktion_update.xlsx`) or **absolute paths**. Only `.xlsx`/`.xls` files are accepted.
   - (Optional) Tick **Run missing imputation**:  
     If checked, `01_WuW_Data.R` applies rule-based replacements using `Fehlende Werte.xlsx`. Missing values coded as `-1` (“don’t know”) or `-2` (“not asked”) are replaced using the most frequent response from Wave 1, following the rules defined in the Excel file.

5. Click **Validate Setup**.  
   The status/log output will check:

   - Presence of subfolders (`01 Raw/`, `02 Parameter/`, `03 R Code/`, `04 Intermediate Results/`, `05 Final Results/`)
   - Presence and naming of the core R scripts and required input files
   - Readability of parameter Excel files

   Any issues will be reported in the Status & Logs / console output.

6. If validation passes, click **Run Pipeline**.  
   The app then:

   - Loads and preprocesses GHHP data (including optional imputation)
   - Imports parameter tables and constructs look-up structures
   - Maps building and system technologies
   - Computes the building heat balance and heat demand
   - Aggregates to final energy demand and annual costs

7. Once the status shows **Run completed**, you can:

   - **Preview Result**: inspect the first rows of the output table.
   - **Histogram**: visualize the distribution of `ebj` (total final energy demand) and see N, min/median/mean/max.
   - **Download Result as CSV**: export the full result table as CSV. The Stata `.dta` result file is written automatically to `05 Final Results/Result_File.dta`.

### 4) Notes and troubleshooting

- **Packages fail to install**
  - Ensure you have a working internet connection and that a CRAN mirror is reachable.
  - You can manually install required packages in R, for example:

    install.packages(c(
      "shiny", "DT", "tools", "haven", "dplyr", "readxl",
      "data.table", "openxlsx", "labelled", "foreign",
      "stringr", "tidyverse", "Rcpp", "magrittr"
    ))

- **Excel file errors**
  - Check that the parameter paths are correct (relative to the project root) and that the files actually exist in `02 Parameter/`.
  - Open each Excel file once in a spreadsheet program to ensure it is not locked or corrupted.

- **`.dta` files not found / wave mismatch**
  - Confirm that the selected **Data wave** in the app corresponds to the GHHP files actually present in `01 Raw/` and that the filenames have not been changed.

- **App cannot detect project root**
  - Manually set the **Project root folder** input to the folder that contains `01 Raw`, `02 Parameter`, `03 R Code`, `04 Intermediate Results`, `05 Final Results`, and `app.R`.

- **Runtime and memory**
  - Typical end-to-end runtime for a single wave is around **1–2 minutes** on a modern desktop and well below 10 minutes even on modest hardware.

If you encounter issues, please note your **R version** (for example the output of `R.version.string`), operating system, and provide any error messages from the app’s **Status & Logs** panel when contacting the maintainers.






