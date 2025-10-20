###############################################################################
#
# Title: 00 Master File
#
# Description: Master file for executing all scripts to calculate final energy demand.
#
# Last update: 24 June 2024
# Authors: Maximilian Dreher, Rene Ladwig, Martina Milcetic (and a little bit Anton Knoche)
#
###############################################################################

# Clean up the working environment
rm(list = ls())

# Change to the directory of this master file
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

# Change to project root (one level up)
setwd("..")

# Base path
user <- getwd()

# Install packages from local zips if not already present (kept behavior)
pkg_files <- list.files("R packages", pattern = "\\.zip$", full.names = TRUE)
for (f in pkg_files) {
  install.packages(f, repos = NULL, type = "binary")
}

# Load packages
packages <- c(
  "Rcpp", "zip", "data.table", "foreign", "haven",
  "labelled", "openxlsx", "readxl", "tidyverse", "dplyr"
)
lapply(packages, library, character.only = TRUE)

# Source files from folder "03 R Code"
setwd(file.path(user, "03 R Code"))


# Define file paths
file_building <- "01 Raw/ariadne_panel1_buildingchars_eng_update24.dta"
file_refurb   <- "01 Raw/ariadne_panel1_experiments_eng_update24.dta"

# Global flag: control whether 01_WuW_Data recodes missing values
run_missing_imputation <<- TRUE


rules <<- "Fehlende Werte.xlsx"   # Roof, Top Floor, External Walls, Basement
u_werte_all <<- "U Werte Baukonstruktion_update.xlsx"   # Roof, Top Floor, External Walls, Basement
u_werte_f   <<- "U und G Werte Fenster_update.xlsx"     # Windows

# Run the pipeline
source("01_WuW_Data.R")
source("02_Individual_Parameters.R")
source("03_System_Technology.R")
source("04_Building_Balance_Sheet.R")
source("05_System_Balance_Sheet.R")

###############################################################################
# References in the code:
# (1) Guideline for Federal Funding for Efficient Buildings – Individual Measures (BEG EM), from 20 May 2021
# (2) Building Energy Act (GEG), from 8 August 2020
# (3) IWU – Short Method Energy Profile (simplified energy assessment of residential buildings)
#     https://www.iwu.de/forschung/energie/kurzverfahren-energieprofil/
###############################################################################
