###############################################################################
#
# Title: 04 Building balance sheet
#
# Description: This script determines the building's heating requirements by
# calculating transmission heat loss and ventilation heat loss.
#
###############################################################################
# ----------------------------------------------------------------------------
### 0. Path specification
# ----------------------------------------------------------------------------

# Clean up the environment (keep only 'user')
rm(list = setdiff(ls(), c("user")))

# Set working directory to the path stored in 'user'
setwd(user)

# Change working directory to "04 Intermediate results"
setwd("04 Intermediate Results")


###############################################################################
# ----------------------------------------------------------------------------
### 1. Load data
# ----------------------------------------------------------------------------

load("02 Datentabellen.RData")
load("01_2 bereinigte Daten.Rdata")

# Keep only required datasets/objects
keep_list <- c("d", "user", "u_aw_long", "u_da_long", "u_fb_long",
               "u_og_long", "u_fe_long", "g_fe_long", 
               "klima_final", "run_missing_imputation")
rm(list = setdiff(ls(), keep_list))


###############################################################################
# ----------------------------------------------------------------------------
### 2. Parameter selection
# ----------------------------------------------------------------------------

# Facade surface coefficients
# Source: IWU (3)
q_Fa <- d$ist1          # ist1: adjacent buildings
q_Fa[q_Fa == 1]  <- 50  # freestanding
q_Fa[q_Fa == 2]  <- 30  # directly adjacent on one side
q_Fa[q_Fa == 3]  <- 10  # directly adjacent on both sides
q_Fa[q_Fa == -1] <- 30  # not specified

# Facade surface coefficient by floor plan
# Source: IWU (3)
p_Fa <- d$ist2            # ist2: building floor plan
p_Fa[p_Fa == 1]  <- 0.66  # compact
p_Fa[p_Fa == 2]  <- 0.8   # elongated/angled/complex
p_Fa[p_Fa == -1] <- 0.66  # not specified

# Partial heating level of attic (sloped roof)
# Source: IWU (3)
f_TBDG <- d$ist7_1a         # ist7_1a: partial heating level attic
f_TBDG[f_TBDG == -2] <- 0   # missing → assume unheated
f_TBDG[f_TBDG == 3]  <- 0   # unheated
f_TBDG[f_TBDG == 1]  <- 1   # fully heated
f_TBDG[f_TBDG == 2]  <- 0.5 # partially heated
f_TBDG[f_TBDG == -1] <- 0.5 # don't know → assume partially heated

# Roof area coefficient (sloped roof)
# Source: IWU (3)
p_Da <- d$ist7_1a
p_Da[p_Da == 1]  <- 1.5   # attic fully heated
p_Da[p_Da == 2]  <- 0.75  # attic partially heated
p_Da[p_Da == 3]  <- 0     # attic unheated
p_Da[p_Da == -2] <- 1.33  # flat roof or missing
p_Da[p_Da == -1] <- 0.75  # don't know

# Top floor area coefficients
# Source: IWU (3)
p_OG <- d$ist7_1a
p_OG[p_OG == 1]  <- 0     # sloped roof & attic fully heated
p_OG[p_OG == 2]  <- 0.67  # sloped roof & attic partially heated
p_OG[p_OG == 3]  <- 1.33  # sloped roof & attic unheated
p_OG[p_OG == -2] <- 0     # flat roof or missing
p_OG[p_OG == -1] <- 0.67  # don't know

# Correction factor for dormers
# Source: IWU (3)
f_Ga <- ifelse(d$ist7_1b == 1, 1.3, 1)  # ist7_1b: dormer windows {Y,N}

# Partial heating level of basement
# Source: IWU (3)
f_TBKG <- d$ist8
f_TBKG[f_TBKG == 1]  <- 1    # fully heated basement
f_TBKG[f_TBKG == 2]  <- 0.5  # partially heated basement
f_TBKG[f_TBKG == 3]  <- 0    # unheated basement
f_TBKG[f_TBKG == 4]  <- 0    # no basement
f_TBKG[f_TBKG == -1] <- 0.5  # don't know

# Air volume factor (room heights)
# Source: IWU (3)
f_L <- ifelse(d$ist3 > 2, 2.5, 2.375)

# Insulation level: roof
f_DDa <- d$ist15_1
f_DDa[f_DDa == 1]  <- 0
f_DDa[f_DDa == 2]  <- 0.25
f_DDa[f_DDa == 3]  <- 0.5
f_DDa[f_DDa == 4]  <- 0.75
f_DDa[f_DDa == 5]  <- 1
f_DDa[f_DDa == -1] <- 0

# Insulation level: top-floor ceiling
f_DOG <- d$ist15_2
f_DOG[f_DOG == 1]  <- 0
f_DOG[f_DOG == 2]  <- 0.25
f_DOG[f_DOG == 3]  <- 0.5
f_DOG[f_DOG == 4]  <- 0.75
f_DOG[f_DOG == 5]  <- 1
f_DOG[f_DOG == -1] <- 0
f_DOG[f_DOG == -2] <- 0  # if attic partially heated: roof insulation relevant → set f_DOG = 0

# Insulation level: external walls
f_DAW <- d$ist15_3
f_DAW[f_DAW == 1]  <- 0
f_DAW[f_DAW == 2]  <- 0.25
f_DAW[f_DAW == 3]  <- 0.5
f_DAW[f_DAW == 4]  <- 0.75
f_DAW[f_DAW == 5]  <- 1
f_DAW[f_DAW == -1] <- 0

# Insulation level: basement ceiling / floor to ground
f_DFB <- d$ist15_4
f_DFB[f_DFB == 1]  <- 0
f_DFB[f_DFB == 2]  <- 0.25
f_DFB[f_DFB == 3]  <- 0.5
f_DFB[f_DFB == 4]  <- 0.75
f_DFB[f_DFB == 5]  <- 1
f_DFB[f_DFB == -1] <- 0

########
# 2.1 Parameter selection for U-values
########

### Roof values
# For roof U-values we assume 20 cm subsequent insulation thickness
ins_roof <- 20

# Federal funding guidelines set minimum technical requirements for roofs
# Source: BEG EM (1)
u_roof_min <- 0.14

# Reference building (residential) in GEG law — reference roof U-value
# Source: GEG (2)
u_roof_ref <- 0.2

### Top-floor values
# For top-floor U-values we assume 20 cm subsequent insulation thickness
ins_uf <- 20

# Federal funding guidelines set minimum technical requirements for top floors
# Source: BEG EM (1)
u_uf_min <- 0.14

# Reference building (residential) in GEG law — reference top-floor U-value
# Source: GEG (2)
u_uf_ref <- 0.2

### Exterior wall values
# For exterior wall U-values we assume 20 cm subsequent insulation thickness
ins_wall <- 20

# Federal funding guidelines set minimum technical requirements for exterior walls
# Source: BEG EM (1)
u_wall_min <- 0.2

# Reference building (residential) in GEG law — reference exterior-wall U-value
# Source: GEG (2)
u_wall_ref <- 0.28

### Floor values
# For floor U-values we assume 13 cm subsequent insulation thickness
ins_floor <- 13

# Federal funding guidelines set minimum technical requirements for floors
# Source: BEG EM (1)
u_floor_min <- 0.25

# Reference building (residential) in GEG law — reference floor U-value
# Source: GEG (2)
u_floor_ref <- 0.35

########
# 2.2 Parameter selection for building calculations
########

# Floor surface parameter
# Source: IWU (3)
p_fb <- 1.33

# Window surface parameter
# Source: IWU (3)
p_fe <- 0.2

########
# 2.3 Parameter selection for transmission heat loss
########

## Temperature correction factors
# Reduction factor for top floor
# Source: IWU (3)
Ft_OG <- 0.8

# Reduction factor for external wall against ground
# Source: IWU (3)
Ft_AW <- 0.6

# Reduction factor for lowest floor
# Source: IWU (3)
Ft_FB <- 0.6

## U-value for thermal bridge losses
# Source: IWU (3)
U_WBZ <- 0.10

########
# 2.4 Parameter selection for ventilation heat loss
########

# Room set-point temperature
# Source: IWU (3)
theta_Soll <- 19

# Reduction factor for time-restricted heating
# Source: IWU (3)
f_z <- 0.95

# Reduction factor for spatially restricted heating
# Source: IWU (3)
f_r <- 1

# Usage factor
# Source: IWU (3)
f_n <- 1

# Combined factor
f_zrn <- f_z * f_r * f_n

# Efficiency factor for heating
# Source: IWU (3)
eta_G <- 0.95


###############################################################################
# ----------------------------------------------------------------------------
### 3. Selection of U-values
# ----------------------------------------------------------------------------

# U-value variants (i ∈ {Da, OG, AW, FB}):
# 1) u_io: original U-value, by year of construction
# 2) u_iKFW: U-value depending on KfW funding
# 3) u_iI: initialized U-values: adjusted components when current standard cannot be inferred
# A fixed insulation thickness (currently 20 cm) is assumed where relevant.

########
### 3.1 Thermal transmittance coefficients (U-values)
########

# The transmission-heat-loss code for roof (u_iKfW) is analogous for top floor, exterior walls, and floor.

### 3.1.1 Roof U-value (i = Da)

# Import original U-values by year of construction
select_Da <- paste0(as.character(d$ist9_1), as.character(d$roof_age))  # ist9_1: roof construction; roof_age: year of construction/insulation
u_DaO <- setDT(u_da_long, key = "selection")[J(select_Da)][, ur_u_wert]

# Apply KfW replacement where applicable
u_DaI <- case_when(d$kfwEM_roo == 1 ~ u_roof_min,
                   d$kfwEH == 1 ~ u_roof_ref * 0.70 ,
                   d$kfwEH == 2 ~ u_roof_ref * 0.85 ,
                   d$kfwEH == 3 ~ u_roof_ref * 1 ,
                   d$kfwEH == 4 ~ u_roof_ref * 1.15 ,
                   d$kfwEH == 5 ~ u_roof_ref * 1.3 ,
                   TRUE~ u_DaO)
                   
                


### 3.1.2 Top-floor U-value (i = OG)

# Import original U-values by year of construction
select_OG <- paste0(as.character(d$ist9_2), as.character(d$upper_floor_age))  # ist9_2: top-floor construction
u_OGO <- setDT(u_og_long, key = "selection")[J(select_OG)][, ur_u_wert]

# Apply KfW replacement where applicable
u_OGI <- case_when(d$kfwEM_tf == 1 ~ u_uf_min,
                   d$kfwEH == 1 ~ u_uf_ref * 0.70 ,
                   d$kfwEH == 2 ~ u_uf_ref * 0.85 ,
                   d$kfwEH == 3 ~ u_uf_ref * 1 ,
                   d$kfwEH == 4 ~ u_uf_ref * 1.15 ,
                   d$kfwEH == 5 ~ u_uf_ref * 1.3 ,
                   TRUE~ u_OGO)


### 3.1.3 Exterior-wall U-value (i = AW)

# Import original U-values by year of construction
select_AW <- paste0(as.character(d$ist9_3), as.character(d$wall_age))  # ist9_3: exterior-wall construction
u_AWO <- setDT(u_aw_long, key = "selection")[J(select_AW)][, ur_u_wert]

# Apply KfW replacement where applicable
u_AWI <- case_when(d$kfwEM_ext == 1 ~ u_wall_min,
                   d$kfwEH == 1 ~ u_wall_ref * 0.70 ,
                   d$kfwEH == 2 ~ u_wall_ref * 0.85 ,
                   d$kfwEH == 3 ~ u_wall_ref * 1 ,
                   d$kfwEH == 4 ~ u_wall_ref * 0.15 ,
                   d$kfwEH == 5 ~ u_wall_ref * 1.3 ,
                   TRUE~ u_AWO)


### 3.1.4 Floor U-value (i = FB)

# Import original U-values by year of construction
select_FB <- paste0(as.character(d$ist9_4), as.character(d$lower_floor_age))  # ist9_4: basement ceiling/floor to ground
u_FBO <- setDT(u_fb_long, key = "selection")[J(select_FB)][, ur_u_wert]

u_FBI <- case_when(d$kfwEM_base == 1 ~ u_floor_min,
                   d$kfwEH == 1 ~ u_floor_ref * 0.70 ,
                   d$kfwEH == 2 ~ u_floor_ref * 0.85 ,
                   d$kfwEH == 3 ~ u_floor_ref * 1 ,
                   d$kfwEH == 4 ~ u_floor_ref * 1.15 ,
                   d$kfwEH == 5 ~ u_floor_ref * 1.3 ,
                   TRUE~ u_FBO)

### 3.1.5 Window U- & G-values

# Import original U- and G-values by predominant glazing and installation year
select_Fe <- paste0(as.character(d$ist11), as.character(d$ist10))  # ist11: glazing; ist10: installation year
u_FeO <- setDT(u_fe_long, key = "selection")[J(select_Fe)][, ur_u_wert]
g_FeO <- setDT(g_fe_long, key = "selection")[J(select_Fe)][, ur_g_wert]

# Convert to numeric
g_FeO <- as.numeric(g_FeO)
u_FeO <- as.numeric(u_FeO)


###############################################################################
# ----------------------------------------------------------------------------
### 4. Pre-calculations: building geometry and areas
# ----------------------------------------------------------------------------

# Number of heated floors
# ist4 (numeric floors) + heated basement + 75% of heated attic
n_G <- d$ist4 + f_TBKG + 0.75 * f_TBDG

# Area of one heated floor
A_HS <- d$ist5a / n_G  # ist5a: total heated living area / number of heated floors

# Area of lowest heated floor
A_FB <- A_HS * p_fb

# Roof area
A_Da <- A_HS * p_Da * f_Ga

# Top-floor area
A_OG <- A_HS * p_OG

# Window area
A_Fe <- d$ist5a * p_fe

# Area of outer wall against ground
A_AWK <- (A_HS * p_Fa + q_Fa) * 0.5 * f_TBKG

# Exterior-wall area
A_AW <- (A_HS * p_Fa + q_Fa) * n_G - A_AWK - A_Fe

# Area of building envelope (sum of exterior elements)
A_tH <- A_FB + A_Da + A_OG + A_Fe + A_AWK + A_AW

# Energy reference area
A_EB <- 0.32 * 4 * d$ist5a

# Air volume
V_L <- f_L * A_EB


###############################################################################
# ----------------------------------------------------------------------------
### 5. Calculations: transmission heat loss
# ----------------------------------------------------------------------------

# Roof transmission heat loss
H_TDa <- u_DaI * A_Da

# Top-floor transmission heat loss
H_TOG <- u_OGI * A_OG * Ft_OG

# Exterior-wall transmission heat loss
H_TAW <- u_AWI * A_AW

# Exterior wall against ground transmission heat loss
H_TAWK <- u_AWI * A_AWK * Ft_AW

# Lower-floor transmission heat loss
H_TFB <- u_FBI * A_FB * Ft_FB

# Window transmission heat loss
H_TFe <- u_FeO * A_Fe

# Thermal bridge losses
H_TWBZ <- U_WBZ * A_tH

# Total transmission heat loss
H_T <- H_TDa + H_TOG + H_TAW + H_TAWK + H_TFB + H_TFe + H_TWBZ
d$H_T <- H_T


###############################################################################
# ----------------------------------------------------------------------------
### 6. Calculations: ventilation heat loss and heating demand
# ----------------------------------------------------------------------------

# Ventilation heat loss
H_V <- 0.7 * 0.34 * V_L

# Energy-efficiency level (h)
h <- round((H_T + H_V) / A_EB, 1)
h[h < 0.7] <- 0.7
h[h > 3]   <- 3

# Climate parameter selection
select_klima <- as.character(h)
t_HP   <- setDT(klima_final, key = "h")[J(select_klima)][, t_HP]
theta_e <- setDT(klima_final, key = "h")[J(select_klima)][, theta_e]
theta_S <- setDT(klima_final, key = "h")[J(select_klima)][, theta_S]

# Degree-day factor
f_GT <- (theta_Soll - theta_e) * t_HP * 0.024

# Heat loss
Q_L <- (H_T + H_V) * f_zrn * f_GT

# Solar heat input (windows)
Q_S <- 0.486 * g_FeO * A_Fe * theta_S

# Internal heat gains
Q_I <- 0.024 * 5 * t_HP * A_EB

# Heating requirement per energy reference area
q_H <- (Q_L - eta_G * (Q_S + Q_I)) / A_EB

###############################################################################
# ----------------------------------------------------------------------------
### 7. Storage
# ----------------------------------------------------------------------------

# Back to base directory
setwd(user)

# Into "04 Intermediate results"
setwd("04 Intermediate Results")

# Save detailed intermediate workspace
save.image("04_1 Bilanz Gebaeude detail.RData")

# Keep only selected variables
keep_list <- c("user", "n_G", "h", "q_H")
rm(list = setdiff(ls(), keep_list))

# Save compact workspace
save.image("04 Bilanz Gebaeude.RData")

# Back to base directory
setwd(user)

# Into "03 R Code"
setwd("03 R Code")


###############################################################################
### References in the code:

# (1) Guideline for Federal Funding for Efficient Buildings – Individual Measures (BEG EM), from May 20, 2021
# (2) Building Energy Act (GEG), from August 8, 2020
# (3) IWU – Short Method Energy Profile (simplified energy assessment of residential buildings)
#     https://www.iwu.de/forschung/energie/kurzverfahren-energieprofil/
