###############################################################################
#
# Title: 01 WuW Data
#
# Description: In this script, the data from the Waerme- & Wohnen-Panel is
# loaded and processed for the subsequent calculation steps.
#
###############################################################################

library(dplyr)

# ----------------------------------------------------------------------------
# 0. Path specification
# ----------------------------------------------------------------------------
# Save important variables
important_vars <- c("user", "run_missing_imputation", "run_retrofit_imputation", "u_werte_all", "u_werte_f","file_building","file_refurb","rules")

# Clean up the environment
rm(list = setdiff(ls(), important_vars))

# Set working directory
setwd(user)

# ----------------------------------------------------------------------------
# 1. Merge data
# ----------------------------------------------------------------------------

# Select Data for Building characteristics
d1 <- haven::read_dta(file_building)

# Select Data for Refurbishment information (keys need to match)
d2 <- haven::read_dta(file_refurb)

# Merge (full join by = "key" (and "year_identifier"))
join_vars <- if ("year_identifier" %in% names(d1) && "year_identifier" %in% names(d2)) {
  c("key", "year_identifier")
} else {
  "key"
}

d <- dplyr::full_join(d1, d2, by = "key")

# Sort and reduce to necessary variables (same logic as before)
columns_to_keep <- c("key", "a*", "id", "ist*", "san*", "year_identifier")

columns_to_keep <- unique(unlist(lapply(columns_to_keep, function(x) grep(x, names(d), value = TRUE))))
d <- d %>% dplyr::select(dplyr::all_of(columns_to_keep))

d <- d %>%
  select(
    key,year_identifier,ist1, ist2, ist3_num, ist4_num, ist5_num, ist5a_num, ist6, ist7_1a, ist7_1b, ist8,
    ist9_1, ist9_2, ist9_3, ist9_4, ist10, ist11, ist12, ist12_1a,
    ist12_2a, ist12_2b, ist12_3a, ist12_5a, ist13, ist13a, ist13a_1,
    ist14, ist14a, ist14b, ist14c, ist15_1, ist15_2, ist15_3,
    ist15_4, ist16a_2, san1a_1a, san1a_13_2, san1a_23_2, san1a_33_2,
    san1a_43_2,san1a_11,san1a_21,san1a_31,san1a_41
  )


# ----------------------------------------------------------------------------
# 2. Data adjustments
# ----------------------------------------------------------------------------
d <- d %>%
  dplyr::mutate(
    ist3  = ist3_num,
    ist4  = ist4_num,
    ist5  = ist5_num,
    ist5a = ist5a_num
  )

# ----------------------------------------------------------------------------
# 3. Identify KfW funding
# ----------------------------------------------------------------------------
d <- d %>%
  dplyr::mutate(
    kfwEH      = 0L,
    kfwEM_roo  = 0L,
    kfwEM_tf   = 0L,
    kfwEM_ext  = 0L,
    kfwEM_base = 0L
  ) %>%
  dplyr::mutate(
    kfwEM_roo  = dplyr::if_else(san1a_13_2 == 1L & (san1a_1a == 6L | san1a_1a == -1L), 1L, kfwEM_roo),
    kfwEM_tf   = dplyr::if_else(san1a_23_2 == 1L & (san1a_1a == 6L | san1a_1a == -1L), 1L, kfwEM_tf),
    kfwEM_ext  = dplyr::if_else(san1a_33_2 == 1L & (san1a_1a == 6L | san1a_1a == -1L), 1L, kfwEM_ext),
    kfwEM_base = dplyr::if_else(san1a_43_2 == 1L & (san1a_1a == 6L | san1a_1a == -1L), 1L, kfwEM_base),
    kfwEH      = dplyr::if_else(san1a_1a >= 1L & san1a_1a <= 5L, san1a_1a, kfwEH)
  )

# ----------------------------------------------------------------------------
# 4. Keep only numeric columns, then cast to numeric
# ----------------------------------------------------------------------------
d <- d %>%
  dplyr::arrange(key) %>%
  dplyr::select(dplyr::where(is.numeric)) %>%                                        # keep only numeric columns
  dplyr::mutate(dplyr::across(dplyr::everything(), ~ suppressWarnings(as.numeric(.)))) %>%  # drop labels
  dplyr::mutate(id = dplyr::row_number())

# ----------------------------------------------------------------------------
# 5. Recode "Don't know" & missing imputation (only if flag is set)
# ----------------------------------------------------------------------------
if (exists("run_missing_imputation") && isTRUE(run_missing_imputation)) {
  
  message("Replacing Missing Values...")
  
  # load rules
  setwd("02 Parameter")
  
  rules_tbl <- read_excel(rules, sheet = "Rules",
                          col_types = c("text","numeric","numeric")) %>%
    rename(variable = 1, old_value = 2, new_value = 3) %>%
    filter(!is.na(variable))
  
  # ---- Apply rules safely to data frame 'd' ----
  apply_rules_safely <- function(d, rules_tbl, verbose = TRUE) {
    # helper: coerce to plain numeric/integer where possible
    coerce_for_compare <- function(x) {
      if (inherits(x, "labelled")) {
        x <- tryCatch(haven::zap_labels(x), error = function(e) x)
      }
      if (is.factor(x)) {
        # keep numeric if levels are numeric, else character compare
        as_num <- suppressWarnings(as.numeric(as.character(x)))
        if (all(is.na(as_num)) && any(!is.na(x))) {
          return(as.character(x))
        } else {
          return(as_num)
        }
      }
      x
    }
    
    vars <- unique(rules_tbl$variable)
    for (var in vars) {
      if (!var %in% names(d)) {
        if (verbose) message(sprintf("• Skip '%s' (not in data).", var))
        next
      }
      sub <- rules_tbl %>% filter(variable == var) %>%
        filter(!is.na(old_value))  # ignore empty rows
      
      # get column and a comparison-friendly copy
      col_orig <- d[[var]]
      col_cmp  <- coerce_for_compare(col_orig)
      
      # build a named map: old -> new (as characters for matching)
      key_old <- as.character(sub$old_value)
      map_new <- sub$new_value
      names(map_new) <- key_old
      
      # indices that match any old_value
      # compare as character to be robust across types
      col_char <- as.character(col_cmp)
      idx <- which(!is.na(col_char) & col_char %in% names(map_new))
      
      if (!length(idx)) {
        if (verbose) message(sprintf("• '%s': no matches to replace.", var))
        next
      }
      
      # compute new values for those indices
      new_vals <- unname(map_new[col_char[idx]])
      
      # If original is factor/labelled, drop to basic type before assignment
      # (tibbles get upset if levels don’t include the new value)
      if (is.factor(col_orig) || inherits(col_orig, "labelled")) {
        col_work <- coerce_for_compare(col_orig)
      } else {
        col_work <- col_orig
      }
      
      # assign: lengths match (no 0-length)
      col_work[idx] <- new_vals
      
      # If you want to keep integers where possible
      if (is.integer(col_orig) && all(!is.na(col_work))) {
        suppressWarnings({
          as_int <- as.integer(col_work)
          # only keep integer if no loss vs numeric
          if (all(is.finite(col_work)) && all(col_work == as_int)) {
            col_work <- as_int
          }
        })
      }
      
      d[[var]] <- col_work
      if (verbose) message(sprintf("✓ '%s': replaced %d value(s).", var, length(idx)))
    }
    d
  }
  
  # ---- Run it ----
  d <- apply_rules_safely(d, rules_tbl, verbose = TRUE)
  
} else {
  message("Skipping missing imputation...")
}

# Adjusting total heated area for apartment buildings and single family homes
d <- d %>%
  dplyr::mutate(
    ist5a = dplyr::case_when(
      ist5a > 0 ~ ist5a,
      ist5a < 0 & ist5 > 0 & ist3 > 0 ~ ist5 * ist3,
      ist5a < 20 ~ NA_real_,
      TRUE ~ NA_real_
    )
  )

# ----------------------------------------------------------------------------
# 7. Account for retrofits (component age classes)
# ----------------------------------------------------------------------------

#Account for all retrofits after 2000
d <- d %>%
  dplyr::mutate(
    roof_age = dplyr::case_when(
      san1a_11 == -2L ~ ist6,
      san1a_11 == -1L ~ ifelse(ist6 > 8L, ist6, 8L),
      san1a_11 %in%  1L:2L  ~ 8L,
      san1a_11 %in%  3L:5L  ~ 9L,
      san1a_11 %in%  6L:7L  ~ 10L,
      san1a_11 %in%  8L:9L  ~ 11L,
      san1a_11 %in% 10L:14L ~ 12L,
      san1a_11 %in% 15L:16L ~ 13L,
      san1a_11 %in% 17L:20L ~ 14L,
      san1a_11 >= 21L       ~ 15L,
      TRUE ~ NA_real_
    ),
    upper_floor_age = dplyr::case_when(
      san1a_21 < 0L ~ ist6,
      san1a_21 == -1L ~ ifelse(ist6 > 8L, ist6, 8L),
      san1a_21 %in%  1L:2L  ~ 8L,
      san1a_21 %in%  3L:5L  ~ 9L,
      san1a_21 %in%  6L:7L  ~ 10L,
      san1a_21 %in%  8L:9L  ~ 11L,
      san1a_21 %in% 10L:14L ~ 12L,
      san1a_21 %in% 15L:16L ~ 13L,
      san1a_21 %in% 17L:20L ~ 14L,
      san1a_21 >= 21L       ~ 15L,
      TRUE ~ NA_real_
    ),
    wall_age = dplyr::case_when(
      san1a_31 < 0L ~ ist6,
      san1a_31 == -1L ~ ifelse(ist6 > 8L, ist6, 8L),
      san1a_31 %in%  1L:2L  ~ 8L,
      san1a_31 %in%  3L:5L  ~ 9L,
      san1a_31 %in%  6L:7L  ~ 10L,
      san1a_31 %in%  8L:9L  ~ 11L,
      san1a_31 %in% 10L:14L ~ 12L,
      san1a_31 %in% 15L:16L ~ 13L,
      san1a_31 %in% 17L:20L ~ 14L,
      san1a_31 >= 21L       ~ 15L,
      TRUE ~ NA_real_
    ),
    lower_floor_age = dplyr::case_when(
      san1a_41 < 0L ~ ist6,
      san1a_41 == -1L ~ ifelse(ist6 > 8L, ist6, 8L),
      san1a_41 %in%  1L:2L  ~ 8L,
      san1a_41 %in%  3L:5L  ~ 9L,
      san1a_41 %in%  6L:7L  ~ 10L,
      san1a_41 %in%  8L:9L  ~ 11L,
      san1a_41 %in% 10L:14L ~ 12L,
      san1a_41 %in% 15L:16L ~ 13L,
      san1a_41 %in% 17L:20L ~ 14L,
      san1a_41 >= 21L       ~ 15L,
      TRUE ~ NA_real_
    )
  )

# Individuals that live in buildings before 1979, didn't retrofit since 2000 and state mostly insulated component get the U-Value for the 1979 - 1983 period

d <- d %>%
  dplyr::mutate(
    roof_age = dplyr::case_when(
      roof_age < 6L & roof_age > 0L & ist15_1 > 3 ~  6L,
      TRUE ~ roof_age
    ),
    upper_floor_age = dplyr::case_when(
      upper_floor_age < 6L & upper_floor_age > 0L & ist15_2 > 3 ~  6L,
      TRUE ~ upper_floor_age
    ),
    wall_age = dplyr::case_when(
      wall_age < 6L & wall_age > 0L & ist15_3 > 3L ~  6L,
      TRUE ~ wall_age
    ),
    lower_floor_age = dplyr::case_when(
      lower_floor_age < 6L & lower_floor_age > 0L & ist15_4 > 3L ~  6L,
      TRUE ~ lower_floor_age
    )
  )

# Clean dataset: drop if missing heating type or too little living space
d <- d %>%
  dplyr::filter(ist12 > 0L,ist4>0, ist5a > 25)

# ----------------------------------------------------------------------------
# 8. Save formatted data
# ----------------------------------------------------------------------------
setwd(user)
setwd("04 Intermediate Results")
save.image("01_2 bereinigte Daten.RData")

setwd(user)
setwd("03 R Code")



