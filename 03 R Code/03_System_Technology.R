###############################################################################
#
# Title: 03 System technology
#
# Description: This script defines the system technology used for space heating
# and hot water production by households in the dataset.
#
###############################################################################
# ----------------------------------------------------------------------------
### 0. Path specification
# ----------------------------------------------------------------------------

rm(list = setdiff(ls(), c("user")))               # Clean up the environment
setwd(user)                                       # Set working directory
setwd("04 Intermediate results")                    # Change to "04 Intermediate results"
options(warn = 0)                                 # Warning behavior: show warnings at completion (default)


###############################################################################
# ----------------------------------------------------------------------------
### 1. Load data
# ----------------------------------------------------------------------------

load("01_2 bereinigte Daten.Rdata")
load("02 Datentabellen.RData")

###############################################################################
# ----------------------------------------------------------------------------
### 2. Space heating (H*)
# ----------------------------------------------------------------------------

########
### 2.1. Heat transfer (variable "Hce")
########
# Manual & thermostatic room-by-room heat transfer
d <- d %>% 
  mutate(
    # ist12_5a: type of room-by-room heating (only asked for room-by-room systems)
    Hce = case_when(
      ist12_5a == -2           ~ "Th",      # question not asked → thermostatic
      !is.na(ist12_5a)         ~ "dMan",    # any other (asked) value → manual
      TRUE                     ~ NA_character_
    )
  )

########
### 2.2. Heat distribution (variable "Hd")
########
d <- d %>%
  mutate(
    Hd = case_when(
      # 1) Base code from ist12: main heating system used
      ist12 == 4 ~ "wo",                                       # individual system per dwelling
      ist12 == 5 ~ "dez",                                      # decentralized room-by-room
      ist12 %in% 1:3 ~ str_c("z",                              # centralized (building-level)
                             # 2) Suffix from building-year questions (ist6 / ist13a_1)
                             case_when(
                               ist6  %in% 1:4                       ~ "70",         # 1970s
                               ist6  %in% 5:6 & ist13a_1 == -2      ~ "70",         # assume 1970s
                               ist6  %in% 5:6 & ist13a_1 %in% 1:3   ~ "70Mod",      # retrofitted 1970s
                               ist6  %in% 7:8                       ~ "90",         # 1990s
                               ist6  %in% 9:15                      ~ "EnEV",       # 2000s+
                               TRUE                                 ~ ""             
                             )
      ),
      TRUE ~ NA_character_
    )
  )

########
### 2.3. Heat storage (variable "Hs")
########
d <- d %>% 
  mutate(
    Hs = case_when(
      ((ist12 == 2 & (ist12_2a == 2 | ist12_2a == 4)) | (ist12 == 5 & ist12_5a == 5)) ~ 
        str_c("PSWP",                                         # base code
              case_when(                                      # year-based suffix
                ist13 %in% 1:5   ~ "94",                      # 1–5 → category 94
                ist13 %in% 6:14  ~ "95",                      # > 5 → category 95
                TRUE             ~ ""                         # missing → no suffix
              )
        ),
      TRUE ~ "zero"
    )
  )

########
### 2.4. Heat generation 1 (variable "Hg1")
########
d <- d %>% 
  mutate(
    # 1) Room-by-room heaters (ist12_5a)
    room_heat = case_when(
      ist12 == 5 & (ist12_5a < 0 | is.na(ist12_5a)) ~ "",       # don’t know / not asked
      ist12 == 5 & ist12_5a == 1                    ~ "Oelofen",
      ist12 == 5 & ist12_5a %in% 2:3                ~ "Ofen",
      ist12 == 5 & ist12_5a == 4                    ~ "GRH",
      ist12 == 5 & ist12_5a == 5                    ~ "EDHG",
      TRUE                                          ~ ""
    ),
    
    # 2) District heating support (ist12 == 3)
    district_heat = if_else(ist12 == 3, "FWU", ""),
    
    # 3) Boilers without condensing < 1995 (ist12 == 1)
    boiler_pre95 = case_when(
      ist12 == 1 & ist13 %in% 1:3 ~ "KTK86",     # ≤ 1986
      ist12 == 1 & ist13 %in% 4:5 ~ "KTK94",     # 1987–1994
      TRUE                        ~ ""
    ),
    
    # 4) Boilers ≥ 1995 (ist12 == 1 & ist13 ≥ 6)
    #    BWK95 = condensing, KTK95 = non-condensing (solid fuel)
    boiler_post95 = case_when(
      ist12 == 1 & ist13 %in% 6:14 & ist12_1a == 4                ~ "KTK95",
      ist12 == 1 & ist13 %in% 6:14 & ist12_1a > 0 & ist12_1a != 4 ~ "BWK95",
      TRUE                                                        ~ ""
    ),
    
    # 5) Gas floor/room boilers (ist12 == 4)
    gas_therme = case_when(
      ist12 == 4 & ist13 %in% 1:5  ~ "GT94",     # up to 1994
      ist12 == 4 & ist13 %in% 6:14 ~ "GBT95",    # 1995+
      TRUE                         ~ ""
    ),
    
    # 6) Heat pumps
    hp_code = case_when(
      # 6a) Central electric-storage HP (“ESz”)
      ist12 == 2 & ist12_2a == 4 ~ "ESz",
      # Central HP (ist12 == 2 & ist12_2a ≠ 4)
      ist12 == 2 & ist12_2a != 4 ~ str_c(
        "WP",                                         # base
        case_when(                                    # heat source
          ist12_2b == 1 ~ "L",                        # air
          ist12_2b == 2 ~ "E",                        # ground
          TRUE          ~ ""
        ),
        case_when(                                    # commissioning year
          ist13 %in% 1:5  ~ "94",                     # ≤ 1995
          ist13 %in% 6:14 ~ "95",                     # ≥ 1996
          TRUE            ~ ""
        ),
        if_else(ist12_2a == 2, "mHS", "")            # electric back-up heater (rod)
      ),
      TRUE ~ ""
    ),
    
    # 7) Final composite variable Hg1
    Hg1 = str_c(room_heat, district_heat, boiler_pre95, boiler_post95, gas_therme, hp_code)
  )

########
### 2.5. Heat generation 2 (variable "Hg2")
########
d <- d %>% 
  mutate(
    Hg2 = case_when(
      # Boiler-type heat pump (ist12_2a == 3)
      ist12_2a == 3 ~ str_c(
        "NTK", 
        case_when(                    # year suffix if known
          ist13 %in% 1:5  ~ "94",     # up to 1995
          ist13 %in% 6:14 ~ "95",     # 1996+
          TRUE            ~ ""        # missing
        )
      ),
      # All other types
      TRUE ~ "zero"
    )
  )

########
### 2.6. Heat energy carrier 1 (variable "Rhet1")
########
d <- d %>% 
  mutate(
    Rhet1 = str_c(
      # 1) Boiler fuel (ist12_1a)
      case_when(
        ist12 == 1 & ist12_1a == 1         ~ "EG",   # natural gas
        ist12 == 1 & ist12_1a == 2         ~ "FG",   # LPG
        ist12 == 1 & ist12_1a %in% c(3, 5) ~ "HO",   # heating oil / other liquid
        ist12 == 1 & ist12_1a == 4         ~ "HP",   # wood pellets
        TRUE                                ~ ""     
      ),
      # 2) District-heating source (ist12_3a)
      case_when(
        ist12 == 3 & ist12_3a == 1         ~ "FW00", # heat-only boiler plant
        ist12 == 3 & ist12_3a == 2         ~ "FW33", # CHP, heat share < 50%
        ist12 == 3 & ist12_3a %in% 3:4     ~ "FW67", # CHP, heat share ≥ 50%
        TRUE                                ~ ""
      ),
      # 3) Heat pump / room-by-room (ist12)
      case_when(
        ist12 == 4 ~ "EG",   # room heaters → natural gas
        ist12 == 2 ~ "S",    # heat pump → electricity
        TRUE        ~ ""
      ),
      # 4) Stove / room heater fuel (ist12_5a)
      case_when(
        ist12 == 5 & ist12_5a == 1 ~ "HO",  # oil stove
        ist12 == 5 & ist12_5a == 2 ~ "SK",  # coal stove
        ist12 == 5 & ist12_5a == 3 ~ "HP",  # wood stove
        ist12 == 5 & ist12_5a == 4 ~ "EG",  # gas room heater
        ist12 == 5 & ist12_5a == 5 ~ "S",   # electric heater/storage
        TRUE                        ~ ""
      )
    )
  )

###############################################################################
# ----------------------------------------------------------------------------
# 3. Hot water (WW)
# ----------------------------------------------------------------------------

########
### 3.1. Hot water distribution (variable "Wd")
########
d <- d %>% 
  mutate(
    Wd = case_when(
      # 1) Decentral hot-water supply (ist14 > 4)
      ist14 %in% 5:8 ~ str_c(
        "d",
        case_when(                            # year suffix
          ist6 %in% 1:8  ~ "90",              # ≤ 2001
          ist6 %in% 9:15 ~ "EnEV",            # 2002 standard
          TRUE           ~ ""
        )
      ),
      # 2) Central hot-water supply (ist14 ≤ 4)
      ist14 %in% 1:4 ~ str_c(
        "z",
        # 2a) Building age / pipe-insulation suffix
        case_when(
          ist6 %in% 9:15                  ~ "EnEV",   # 2002+
          ist6 %in% 1:5 & ist14c != 1     ~ "70",     # no insulation / DK
          ist6 %in% 1:5 & ist14c == 1     ~ "70Mod",  # insulation
          ist6 %in% 6:8                   ~ "90",
          TRUE                            ~ ""
        ),
        # 2b) Circulation suffix
        case_when(
          ist14b == 1 ~ "oZ",   # without hot-water loop
          ist14b == 2 ~ "mZ",   # with hot-water loop
          TRUE        ~ ""
        )
      ),
      TRUE ~ NA_character_
    )
  )

########
### 3.2. Hot water storage (variable "Ws")
########
d <- d %>% 
  mutate(
    Ws = case_when(
      # 1) Central DHW storage (ist14 = 3)
      ist14 == 3 ~ str_c(
        "ZS",
        case_when(                 # year suffix from ist6
          ist6 %in% 1:7  ~ "94",  # ≤ 1994
          ist6 %in% 8:15 ~ "95",  # 1995+
          TRUE           ~ ""
        )
      ),
      # 2) Gas-fired DHW storage (ist14 = 2)
      ist14 == 2 ~ "GS",
      # 3) Electric / small electric storage (ist14 = 8)
      ist14 == 8 ~ str_c(
        "EKS",
        case_when(                 # year suffix from ist6
          ist6 %in% 1:7  ~ "94",  # ≤ 1994
          ist6 %in% 8:15 ~ "95",  # 1995+
          TRUE           ~ ""
        )
      ),
      # 4) Instantaneous heaters / floor heating (ist14 = 1,4,5,6,7)
      ist14 %in% c(1, 4, 5, 6, 7) ~ "zero",
      TRUE ~ NA_character_
    )
  )

########
### 3.3. Hot water generator 1 (variable "Wg1")
########
d <- d %>% 
  mutate(
    Wg1 = case_when(
      # 1) DHW produced by same generator as space heating (ist14 = 1) → reuse Hg1
      ist14 == 1 ~ Hg1,
      # 2) Gas-fired DHW storage tank (ist14 = 2)
      ist14 == 2 ~ "GS",
      # 3) Central electric storage tank (ist14 = 3)
      ist14 == 3 ~ "ESz",
      # 4) Electric HP, basement air, year suffix, with rod heater (ist14 = 4)
      ist14 == 4 ~ str_c(
        "WPK",
        case_when(                        # year suffix from ist6
          ist6 %in% 1:7  ~ "94",
          ist6 %in% 8:15 ~ "95",
          TRUE           ~ ""
        ),
        if_else(ist12_2a == 2, "mHS", "")   # heating-rod present → mHS
      ),
      # 5) Gas floor / combi boiler (GT) (ist14 = 5)
      ist14 == 5 ~ str_c(
        "GT",
        case_when(
          ist6 %in% 1:7  ~ "94",
          ist6 %in% 8:15 ~ "95",
          TRUE           ~ ""
        )
      ),
      # 6) Decentral gas instantaneous heater (GDH) (ist14 = 6)
      ist14 == 6 ~ str_c(
        "GDH",
        case_when(
          ist6 %in% 1:7  ~ "94",
          ist6 %in% 8:15 ~ "95",
          TRUE           ~ ""
        )
      ),
      # 7) Decentral electric instantaneous heater (ist14 = 7)
      ist14 == 7 ~ "EDH",
      # 8) Decentral small electric storage unit (ist14 = 8)
      ist14 == 8 ~ "EKS",
      TRUE ~ NA_character_
    )
  )

########
### 3.4. Hot water generator 2 (variable "Wg2")
########
d <- d %>% 
  mutate(
    Wg2 = case_when(
      # Central hot-water supply AND solar-thermal system present
      ist14 %in% 1:4 & ist16a_2 == 1 ~ "TSA",
      # Otherwise
      TRUE                           ~ "zero"
    )
  )

########
### 3.5. Hot water energy carrier 1 (variable "WWet1")
########
d <- d %>% 
  mutate(
    WWet1 = str_c(
      # 1) If DHW is combined with space-heating (ist14 == 1) → reuse Rhet1
      if_else(ist14 == 1, Rhet1, ""),
      # 2) Otherwise derive from DHW supply type
      case_when(
        ist14 %in% c(2, 5, 6)    ~ "EG",   # natural gas
        ist14 %in% c(3, 4, 7, 8) ~ "S",    # electricity
        TRUE                     ~ ""      # combined or N/A
      )
    )
  )

###############################################################################
# ----------------------------------------------------------------------------
### 4. Save system-technology parameters
# ----------------------------------------------------------------------------

setwd(user)                          # Back to base directory
setwd("04 Intermediate Results")       # Into "04 Intermediate results"

save.image("03 Kuerzel Anlagentechnik.RData")  # Save current workspace

setwd(user)                          # Back to base directory
setwd("03 R Code")                   # Into "03 R Code"

