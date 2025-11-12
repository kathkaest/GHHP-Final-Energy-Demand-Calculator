# GHHP-Final-Energy-Demand-Calculator: R-Tool and Shiny App to calculate Final Energy Demand for Households in German Heating and Housing Panel

This repository provides and documents an R-package which computes the building energy demand (EBJ) for households in the German Heating and Housing Panel data set. Moreover, it directly ships with a Shiny app UI to run the pipeline.

## Abstract Tool

The present code of the "GHHP-Final-Energy-Demand-Calculator" package calculates the final energy demand and the resulting heating costs of residential buildings based on building characteristics (e.g., wall structure, window glazing) and the installed building services equipment using the statistical software R. The final energy demand indicates how much energy is needed to heat the building, supply it with hot water, ventilate it, and cool it. It is therefore an important parameter for the energy efficiency of a residential building. The calculation is based on the "short energy profile method" (Loga et al. 2005). All important parameters are based on the German Energy Saving Ordinance (EnEV) from 2002 (EnEV 2002/dena Energy Passport Working Aid). The short method consists of three parts: the area estimation method, the calculation of flat-rate heat transfer coefficients (U-values), and the calculation of flat-rate values for building services.
The primary parameters that can be calculated in this way are the final energy demand in kWh/sqm*a, the absolute energy costs in Euro/a, and the energy standard of the building in W/(sqm K).

## Data Access

The building data used for the calculation comes from the German Heating and Housing Panel [https://www.rwi-essen.de/en/research-advice/further/research-data-center-ruhr-fdz/data-sets/microdata/german-heating-and-housing-panel](https://www.rwi-essen.de/en/research-advice/further/research-data-center-ruhr-fdz/data-sets/microdata/german-heating-and-housing-panel) established as part of the Kopernikus Ariadne project funded by the Federal Ministry of Education and Research (BMBF)
The calculations will take approximately one minute.
The data are available to researchers for non-commercial use. The data can be obtained in both .csv and .dta file formats. It should be noted that data access to both versions requires a signed data use agreement. Both versions are restricted to non-commercial research.

Data access is provided by the Research Data Centre Ruhr at the RWI - Leibniz Institute for Economic Research (FDZ Ruhr). The data can be accessed at [https://www.rwi-essen.de/en/research-advice/further/research-data-center-ruhr-fdz/data-access](https://www.rwi-essen.de/en/research-advice/further/research-data-center-ruhr-fdz/data-access). The application form includes a brief description and title of the project, potential cooperation, information on the applying department, expected duration of data usage as well as further participants in the project. 

Data users shall cite the datasets properly with the respective DOIs. The DOIs of the current versions of the data sets including the building characteristics from the GHHP data are: 

**Scientific Use File (SUF) Wave 1 2021:** [https://doi.org/10.7807/ghhp:building:v1](https://doi.org/10.7807/ghhp:building:v1)

**Scientific Use File (SUF) Wave 2 2022:** [https://doi.org/10.7807/GHHP:BUILDING:V2](https://doi.org/10.7807/GHHP:BUILDING:V2)

## More Information

- Repository for V1.1: Enter Zenodo-Link here

- If you use this tool, please cite it as shown under "Cite this repository"

## Contact Person

Please contact [Dr. Kathrin Kaestner](https://www.rwi-essen.de/en/rwi/team/person/kathrin-kaestner) in case of questions.

## Disclaimer

All rights reserved to RWI and the authors of the code, [Prof. Dr. Andreas Gerster](https://environmental.economics.uni-mainz.de/team/andreas-gerster/), [Dr. Kathrin Kaestner](https://www.rwi-essen.de/en/rwi/team/person/kathrin-kaestner), [Anton Knoche](https://www.pik-potsdam.de/members/antonkn/homepage), [Martina Milcetic](https://environmental.economics.uni-mainz.de/team-martina-milcetic-phd-candidate/), and [Jan Schweers](https://environmental.economics.uni-mainz.de/team/team-jan-schweers-phd-candidate/). Please note that the terms of conditions of each library apply.

## Further Tool Instructions

### 1) Requirements
- R (4.2+ recommended): https://cran.r-project.org/
- Optional: RStudio (latest): https://posit.co/download/rstudio-desktop/
- Internet connection (the app installs any missing R packages from CRAN automatically on first run)

### 2) Folder layout (expected)
- `01 Raw/` (the data sets can be accessed through the Data Centre Ruhr at RWI, see Data Access Bullet above)
  - `ariadne_panel1_buildingchars_eng_update24.dta`
  - `ariadne_panel1_experiments_eng_update24.dta`
  - `ariadne_panel2_buildingchars_eng.dta`
  - `ariadne_panel2_experiments_eng.dta`
- `02 Parameter/`
  - `Fehlende Werte.xlsx`
  - `U Werte Baukonstruktion_update.xlsx`
  - `U und G Werte Fenster_update.xlsx`
  - `Klimakoeffizienten.xlsx`
  - `Kosten pro Energietraeger.xlsx`
  - `Waermekennwerte Anlagentechnik.xlsx`
- `03 R Code/`
  - `00_Master_File.R`
  - `01_WuW_Data.R`
  - `02_Individual_Parameters.R`
  - `03_System_Technology.R`
  - `04_Building_Balance_Sheet.R`
  - `05_System_Balance_Sheet.R`
- `04 Intermediate Results/` (created/used by the pipeline)
- `05 Final Results/` (output folder; contains `Result_File.dta` after successful run)
- `app.R` (Shiny app starter)

The app attempts to auto-detect the project root based on these folders.

### 3) How to run the Shiny app (in R / RStudio)
1. Open R or RStudio.
2. Set the working directory to the project folder in which you saved all downloaded documents `[YOUR PROJECT FOLDER NAME]`:
   - In R: `setwd("C:/path/to/~[YOUR PROJECT FOLDER NAME]")`
   - In RStudio: Session --> Set Working Directory --> Choose the project folder
3. Launch the app by running:
   - `source("app.R")`  (or)  `shiny::runApp(".")`
4. In the app sidebar:
   - Confirm the auto-detected `Project root folder` is correct.
   - Choose the `Data wave` (Wave 1 or Wave 2):
     - Wave 1: uses `ariadne_panel1_buildingchars_eng_update24.dta` and `ariadne_panel1_experiments_eng_update24.dta`
     - Wave 2: uses `ariadne_panel2_buildingchars_eng.dta` and `ariadne_panel2_experiments_eng.dta`
   - Provide the parameter Excel files (text inputs accept relative paths like `02 Parameter/...` or absolute paths). Only `.xlsx`/`.xls` are accepted.
   - Click `Validate Setup` - fix any reported issues.
   - Click `Run Pipeline` - this sources the scripts under `03 R Code/` and writes `05 Final Results/Result_File.dta`.
5. Use the `Preview Result` and `Histogram` tabs to view outputs; use `Download Result as CSV` to export a CSV.

### 4) Notes and troubleshooting
- Packages fail to install:
  - Ensure you have internet access and a CRAN mirror is reachable.
  - You can manually run in R: `install.packages(c("shiny","DT","tools","haven","dplyr","readxl","data.table","openxlsx","labelled","foreign","stringr","tidyverse","Rcpp","magrittr"))`
- Excel file errors:
  - Confirm paths are correct (relative to project root) and the files exist in `02 Parameter/`.
  - Open each file once in Excel to confirm it's not locked/corrupted.
- `.dta` files not found:
  - Confirm the selected wave matches the files present in `01 Raw/`.
- App cannot detect project root:
  - Manually set the `Project root folder` input to the folder containing `01 Raw`, `02 Parameter`, `03 R Code`, etc.

If you have issues, please provide your R version (`R.version.string`) and any error messages from the app's Status & Logs tab.
