###############################################################################
#
# Title: 05 Balance sheet – system technology
#
# Description: This script calculates final energy demand as a function of the
# final energy demand for hot water and for space heating.
#
###############################################################################
# ----------------------------------------------------------------------------
# 0. Path specification
# ----------------------------------------------------------------------------

# Clean up the environment (keep only 'user')
rm(list = setdiff(ls(), c("user")))

# Set working directory to the path stored in 'user'
setwd(user)

# Change working directory to "04 Intermediate results"
setwd("04 Intermediate Results")

# Working directory (no-op, preserved for parity)
getwd()

# dplyr used for clearer vector logic (no behavior changes)
library(dplyr)

###############################################################################
# ----------------------------------------------------------------------------
# 1. Import data
# ----------------------------------------------------------------------------

load("01_2 bereinigte Daten.Rdata")
load("02 Datentabellen.RData")
load("03 Kuerzel Anlagentechnik.RData")
load("04 Bilanz Gebaeude.RData")

###############################################################################
# ----------------------------------------------------------------------------
# 2. Hot water parameters
# ----------------------------------------------------------------------------

# Number of heated floors → grouping used in parameter tables
ng1 <- case_when(
  n_G > 5      ~ "6 und mehr",
  n_G <= 2     ~ "1 bis 2",
  TRUE         ~ "3 bis 5"
)

# Number of residential units (ist3) → two different groupings used below
ng2 <- case_when(
  d$ist3 <= 2  ~ "1 bis 2",
  TRUE         ~ "3 und mehr"
)
ng3 <- case_when(
  d$ist3 >= 8  ~ "8 und mehr",
  d$ist3 <= 2  ~ "1 bis 2",
  TRUE         ~ "3 bis 7"
)

# Useful heat demand (assumption) — Source: IWU (3)
q_w <- 12.5

# Hot water distribution: heat loss
select_q_wd <- paste0(d$Wd, ng1) 
q_wd <- as.numeric(setDT(Q_wd, key = "selection")[J(select_q_wd)][, value])

# Hot water storage: heat loss
select_q_ws <- paste0(d$Ws, ng3) 
q_ws <- as.numeric(setDT(Q_ws, key = "selection")[J(select_q_ws)][, value])

# Auxiliary flag for coverage share 1 (central DHW if ist14 in 1:4)
t <- new.env()
t$aux1 <- ifelse(d$ist14 > 0 & d$ist14 <= 4, 1, 0)

# Coverage share 1 (solar-thermal central WW reduces share to 0.6)
alpha_wg1 <- ifelse(t$aux1 * d$ist16a_2 == 1, 0.6, 1)
rm(t)

# Hot water generation: producer effort figure 1
select_e_wg1 <- paste0(d$Wg1, ng2) 
e_wg1 <- as.numeric(setDT(E_wg, key = "selection")[J(select_e_wg1)][, value])

# Producer coverage share 2
alpha_wg2 <- 1 - alpha_wg1

# Hot water generation: producer effort figure 2
select_e_wg2 <- paste0(d$Wg2, ng2) 
e_wg2 <- as.numeric(setDT(E_wg, key = "selection")[J(select_e_wg2)][, value])

# Hot water distribution: auxiliary electricity requirement
select_q_wdhe <- paste0(d$Wd, ng2) 
q_wdhe <- as.numeric(setDT(Q_wdhe, key = "selection")[J(select_q_wdhe)][, value])

# Hot water storage: auxiliary electricity requirement
select_q_wshe <- paste0(d$Ws, ng2) 
q_wshe <- as.numeric(setDT(Q_wshe, key = "selection")[J(select_q_wshe)][, value])

# Hot water generation: auxiliary electricity requirement 1
select_q_wghe1 <- paste0(d$Wg1, ng2) 
q_wghe1 <- as.numeric(setDT(Q_wghe, key = "selection")[J(select_q_wghe1)][, value])

# Hot water generation: auxiliary electricity requirement 2
select_q_wghe2 <- paste0(d$Wg2, ng2) 
q_wghe2 <- as.numeric(setDT(Q_wghe, key = "selection")[J(select_q_wghe2)][, value])

###############################################################################
# ----------------------------------------------------------------------------
# 3. Space heating parameters
# ----------------------------------------------------------------------------

# Heating credit from distribution
select_q_hwd <- paste0(d$Wd, ng1)
q_hwd <- as.numeric(setDT(Q_hwd, key = "selection")[J(select_q_hwd)][, value])

# Heating credit from storage
select_q_hws <- paste0(d$Ws, ng3)
q_hws <- as.numeric(setDT(Q_hws, key = "selection")[J(select_q_hws)][, value])

# Heat transfer: heat loss
q_hce <- as.numeric(setDT(Q_hce, key = "selection")[J(d$Hce)][, value])

# Heat distribution: heat loss
select_q_hd <- paste0(d$Hd, ng1)
q_hd <- as.numeric(setDT(Q_hd, key = "selection")[J(select_q_hd)][, value])

# Heat storage: heat loss
select_q_hs <- paste0(d$Hs, ng2)
q_hs <- as.numeric(setDT(Q_hs, key = "selection")[J(select_q_hs)][, value])

# Climate coefficient: correction factor for heating period
select_klima <- as.character(h)
f_HP <- setDT(klima_final, key = "h")[J(select_klima)][, f_HP]

# Producer coverage share 1 (boiler-type HP gets 0.8 share)
alpha_hg1 <- ifelse(d$ist12_2a == 3, 0.8, 1)

# Heat generation: producer effort figure 1
select_e_hg1 <- paste0(d$Hg1, ng2)
e_hg1 <- as.numeric(setDT(E_hg, key = "selection")[J(select_e_hg1)][, value])

# Producer coverage share 2
alpha_hg2 <- 1 - alpha_hg1

# Heat generation: producer effort figure 2
select_e_hg2 <- paste0(d$Hg2, ng2)
e_hg2 <- as.numeric(setDT(E_hg, key = "selection")[J(select_e_hg2)][, value])

# Heat transfer: auxiliary electricity requirement
q_hcehe <- as.numeric(setDT(Q_hcehe, key = "selection")[J(d$Hce)][, value])

# Heat distribution: auxiliary electricity requirement
select_q_hdhe <- paste0(d$Hd, ng2)
q_hdhe <- as.numeric(setDT(Q_hdhe, key = "selection")[J(select_q_hdhe)][, value])

# Heat storage: auxiliary electricity requirement
select_q_hshe <- paste0(d$Hs, ng2)
q_hshe <- as.numeric(setDT(Q_hshe, key = "selection")[J(select_q_hshe)][, value])

# Heat generation: auxiliary electricity requirement 1
select_q_hghe1 <- paste0(d$Hg1, ng2)
q_hghe1 <- as.numeric(setDT(Q_hghe, key = "selection")[J(select_q_hghe1)][, value])

# Heat generation: auxiliary electricity requirement 2
select_q_hghe2 <- paste0(d$Hg2, ng2)
q_hghe2 <- as.numeric(setDT(Q_hghe, key = "selection")[J(select_q_hghe2)][, value])

###############################################################################
# ----------------------------------------------------------------------------
# 4. Final energy demand (EBJ)
# ----------------------------------------------------------------------------

### Hot water
# Total heat demand for hot water
q_wstar <- q_w + q_wd + q_ws

# Final energy (WW) – generator 1 (excl. auxiliaries)
q_ew1 <- q_wstar * (e_wg1 * alpha_wg1)

# Final energy (WW) – generator 2 (excl. auxiliaries)
q_ew2 <- q_wstar * (e_wg2 * alpha_wg2)

# Final energy (WW) – auxiliaries
q_hew <- q_wdhe + q_wshe + (q_wghe1 * alpha_wg1) + (q_wghe2 * alpha_wg2)

# Final energy demand for hot water
q_ww <- q_ew1 + q_ew2 + q_hew

### Space heating
# Heating credit
q_hw <- q_hwd + q_hws

# Total heat requirement for space heating
q_hstar <- q_H + f_HP * (-q_hw + q_hce + q_hd + q_hs)

# Final energy (RH) – generator 1 (excl. auxiliaries)
q_eh1 <- q_hstar * (e_hg1 * alpha_hg1)

# Final energy (RH) – generator 2 (excl. auxiliaries)
q_eh2 <- q_hstar * (e_hg2 * alpha_hg2)

# Final energy (RH) – auxiliaries
q_heh <- f_HP * (q_hcehe + q_hdhe + q_hshe + (q_hghe1 * alpha_hg1) + (q_hghe2 * alpha_hg2))

# Final energy demand for space heating
q_rh <- q_eh1 + q_eh2 + q_heh

### Total final energy demand heating and hot water
d$nbj <- q_H 
d$ebj_ww <- q_ww 
d$ebj_rh <- q_rh  
d$ebj <- q_ww + q_rh

###############################################################################
# ----------------------------------------------------------------------------
# 5. Current costs (KDJ)
# ----------------------------------------------------------------------------

# Price WW energy carrier 1
p_wwet1 <- as.numeric(setDT(kosten_et, key = "ET")[J(d$WWet1)][, Kosten])

# Total WW costs (A_EB factor 1.28 because energy reference area ≠ living area)
K_ww <- p_wwet1 * q_ew1 * d$ist5 * 1.28 / 100

# Price RH energy carrier 1
p_rhet1 <- as.numeric(setDT(kosten_et, key = "ET")[J(d$Rhet1)][, Kosten])

# Total space-heating costs
K_rh <- p_rhet1 * q_eh1 * d$ist5 * 1.28 / 100

# Absolute annual costs (EUR/year)
d$kdj <- K_ww + K_rh

###############################################################################
# ----------------------------------------------------------------------------
# 6. Merge and store
# ----------------------------------------------------------------------------

# Back to base directory
setwd(user)

# Change to "05 Final results" (kept original directory name)
setwd("05 Final Results")

# Export to Stata format
write_dta(d, "Result_File.dta")

# Convert to data.frame (kept for parity)
df <- as.data.frame(d)

# Optional exports (Excel / CSV) — kept commented as in original
# write.xlsx(df, file = "Result_File.xlsx")
# write.csv(df, file = "Result_File.csv")


if (all(d$ebj[!is.na(d$ebj)] >= 1 & d$ebj[!is.na(d$ebj)] <= 1000)) {
  message("Calculated ebjs plausible...\n")
} else {
  message("Calculated ebjs not plausible...\n")
}

###############################################################################
# References in the code:
# (1) Guideline for Federal Funding for Efficient Buildings – Individual Measures (BEG EM), from May 20, 2021
# (2) Building Energy Act (GEG), from August 8, 2020
# (3) IWU – Short Method Energy Profile (simplified energy assessment of residential buildings)
#     https://www.iwu.de/forschung/energie/kurzverfahren-energieprofil/

