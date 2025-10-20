###############################################################################
# Title: 02 Individual parameters
###############################################################################

# --- 0. Path specification ---------------------------------------------------

rm(list = setdiff(ls(), c("user", "u_werte_all", "u_werte_f", "klima_file", "kosten_file", "waerme_file")))

setwd(user)
setwd("02 Parameter")

options(warn = -1)

# Helper: add a trailing "zero" row (keeps original matrix->character coercion)
addzero <- function(m) {
  n <- ncol(m) - 1
  zero <- c("zero", rep(0, n))
  rbind(m, zero)
}

# Helper: convert wide -> long for U-values (roof/top floor/wall/floor)
u_wide_to_long <- function(wide_dt, id_names = c("Konstr_cat", "Konstr"), value_name = "ur_u_wert") {
  names(wide_dt) <- c(id_names, 1:15, -1)
  long <- data.table::melt(wide_dt, id = id_names)
  names(long) <- c(id_names, "date", value_name)
  long %>%
    mutate(selection = paste0(as.character(.data[[id_names[1]]]),
                              as.character(.data[["date"]])))
}

# --- 1. U-values building construction ---------------------------------------

coln_u <- c("Konstr_cat", "Konstr", 1:15, -1)

# Roof
u_da_wide <- suppressMessages(readxl::read_xlsx(u_werte_all, range = "Tabelle1!B3:R5", col_names = FALSE)) %>%
  data.table::as.data.table() %>%
  {.[c(2,3), ] <- .[c(3,2), ]; .} %>%                       # swap rows 2 and 3
  cbind(c(1:2, -1), .)
names(u_da_wide) <- coln_u
u_da_long <- u_wide_to_long(u_da_wide)
rm(u_da_wide)

# Top floor ceiling
u_og_wide <- suppressMessages(readxl::read_xlsx(u_werte_all, range = "Tabelle1!B6:R8", col_names = FALSE)) %>%
  data.table::as.data.table() %>%
  {.[c(2,3), ] <- .[c(3,2), ]; .} %>%
  cbind(c(1:2, -1), .)
names(u_og_wide) <- coln_u
u_og_long <- u_wide_to_long(u_og_wide)
rm(u_og_wide)

# Exterior wall
u_aw_wide <- suppressMessages(readxl::read_xlsx(u_werte_all, range = "Tabelle1!B10:R12", col_names = FALSE)) %>%
  data.table::as.data.table() %>%
  {.[c(2,3), ] <- .[c(3,2), ]; .} %>%
  cbind(c(1:2, -1), .)
names(u_aw_wide) <- coln_u
u_aw_long <- u_wide_to_long(u_aw_wide)
rm(u_aw_wide)

# Floor
u_fb_wide <- suppressMessages(readxl::read_xlsx(u_werte_all, range = "Tabelle1!B13:R15", col_names = FALSE)) %>%
  data.table::as.data.table() %>%
  {.[c(2,3), ] <- .[c(3,2), ]; .} %>%
  cbind(c(1:2, -1), .)
names(u_fb_wide) <- coln_u
u_fb_long <- u_wide_to_long(u_fb_wide)
rm(u_fb_wide)

# --- 2. U-values windows + G-values windows ---------------------------------

coln_u <- c("Fenster_cat", "Fenster", 1:15, -1)

# U-values windows
u_fe_wide <- suppressMessages(readxl::read_xlsx(u_werte_f, na = "–", range = "Tabelle1!B3:R8", col_names = FALSE)) %>%
  data.table::as.data.table() %>%
  {data.table::rbindlist(list(.[-1, ], .[1, ]), use.names = FALSE)} %>%
  cbind(c(1:5, -1), .)
names(u_fe_wide) <- coln_u
u_fe_long <- data.table::melt(u_fe_wide, id = c("Fenster_cat", "Fenster")) %>%
  as.data.frame() %>%
  rename(date = variable, ur_u_wert = value) %>%
  mutate(selection = paste0(as.character(Fenster_cat), as.character(date)))
rm(u_fe_wide)

# G-values windows
g_fe_wide <- suppressMessages(readxl::read_xlsx(u_werte_f, na = "–", range = "Tabelle1!B9:R14", col_names = FALSE)) %>%
  data.table::as.data.table() %>%
  {data.table::rbindlist(list(.[-1, ], .[1, ]), use.names = FALSE)} %>%
  cbind(c(1:5, -1), .)
names(g_fe_wide) <- coln_u
g_fe_long <- data.table::melt(g_fe_wide, id = c("Fenster_cat", "Fenster")) %>%
  as.data.frame() %>%
  rename(date = variable, ur_g_wert = value) %>%
  mutate(selection = paste0(as.character(Fenster_cat), as.character(date)))
rm(g_fe_wide)

# --- 3. Climate coefficients -------------------------------------------------

coln_klima <- c("coef", seq(0.7, 3, 0.1))

klima_path <- if (exists("klima_file") && is.character(klima_file) && nzchar(klima_file)) klima_file else "Klimakoeffizienten.xlsx"
klima_koef <- suppressMessages(readxl::read_xlsx(klima_path, na = "–",
                                                 range = "Tabelle1!B4:Y8", col_names = FALSE)) %>%
  data.table::as.data.table() %>%
  cbind(c("theta_HG", "t_HP", "f_HP", "theta_e", "theta_S"), .)
names(klima_koef) <- coln_klima
klima_long  <- data.table::melt(klima_koef, id = "coef")
names(klima_long) <- c("coef", "h", "value")
klima_final <- data.table::dcast(klima_long, h ~ coef)
rm(klima_koef, klima_long)

# --- 4. Costs per energy source ----------------------------------------------

coln_kosten_et <- c("ET", "ET_long", "Kosten")
kosten_path <- if (exists("kosten_file") && is.character(kosten_file) && nzchar(kosten_file)) kosten_file else "Kosten pro Energietraeger.xlsx"
kosten_et <- suppressMessages(readxl::read_xlsx(kosten_path, na = "–",
                                                range = "Tabelle1!B6:D16", col_names = FALSE)) %>%
  data.table::as.data.table()
names(kosten_et) <- coln_kosten_et

# --- 5. Hot water distribution: Wd ------------------------------------------

# 5.1 Heat loss
coln <- c("Kuerzel", "1 bis 2", "3 bis 5", "6 und mehr")
waerme_path <- if (exists("waerme_file") && is.character(waerme_file) && nzchar(waerme_file)) waerme_file else "Waermekennwerte Anlagentechnik.xlsx"
Q_wd <- suppressMessages(readxl::read_xlsx(waerme_path, na = "–",
                                           range = "Tabelle1!A5:F14", col_names = FALSE)) %>%
  as.matrix() %>%
  {.[, c(1, 4:6)]} %>%
  addzero() %>%
  data.table::as.data.table()
names(Q_wd) <- coln
Q_wd <- data.table::melt(Q_wd, id = "Kuerzel", variable.name = "nG") %>%
  mutate(selection = paste0(as.character(Kuerzel), as.character(nG)))

# 5.2 Heating credit
coln <- c("Kuerzel", "1 bis 2", "3 bis 5", "6 und mehr")
Q_hwd <- suppressMessages(readxl::read_xlsx(waerme_path, na = "–",
                                            range = "Tabelle1!A5:I14", col_names = FALSE)) %>%
  as.matrix() %>%
  {.[, c(1, 7:9)]} %>%
  addzero() %>%
  data.table::as.data.table()
names(Q_hwd) <- coln
Q_hwd <- data.table::melt(Q_hwd, id = "Kuerzel", variable.name = "nG") %>%
  mutate(selection = paste0(as.character(Kuerzel), as.character(nG)))

# 5.3 Auxiliary energy requirement
coln <- c("Kuerzel", "1 bis 2", "3 und mehr")
Q_wdhe <- suppressMessages(readxl::read_xlsx(waerme_path, na = "–",
                                             range = "Tabelle1!A5:K14", col_names = FALSE)) %>%
  as.matrix() %>%
  {.[, c(1, 10:11)]} %>%
  addzero() %>%
  data.table::as.data.table()
names(Q_wdhe) <- coln
Q_wdhe <- data.table::melt(Q_wdhe, id = "Kuerzel", variable.name = "nW") %>%
  mutate(selection = paste0(as.character(Kuerzel), as.character(nW)))

# --- 6. Hot water storage: Ws -----------------------------------------------

# 6.1 Heat loss
coln <- c("Kuerzel", "1 bis 2", "3 bis 7", "8 und mehr")
Q_ws <- suppressMessages(readxl::read_xlsx(waerme_path, na = "–",
                                           range = "Tabelle1!A19:F23", col_names = FALSE)) %>%
  as.matrix() %>%
  {.[, c(1, 4:6)]} %>%
  addzero() %>%
  data.table::as.data.table()
names(Q_ws) <- coln
Q_ws <- data.table::melt(Q_ws, id = "Kuerzel", variable.name = "nW") %>%
  mutate(selection = paste0(as.character(Kuerzel), as.character(nW)))

# 6.2 Heating credit
coln <- c("Kuerzel", "1 bis 2", "3 bis 7", "8 und mehr")
Q_hws <- suppressMessages(readxl::read_xlsx(waerme_path, na = "–",
                                            range = "Tabelle1!A19:I23", col_names = FALSE)) %>%
  as.matrix() %>%
  {.[, c(1, 7:9)]} %>%
  addzero() %>%
  data.table::as.data.table()
names(Q_hws) <- coln
Q_hws <- data.table::melt(Q_hws, id = "Kuerzel", variable.name = "nW") %>%
  mutate(selection = paste0(as.character(Kuerzel), as.character(nW)))

# 6.3 Auxiliary energy requirement
coln <- c("Kuerzel", "1 bis 2", "3 und mehr")
Q_wshe <- suppressMessages(readxl::read_xlsx(waerme_path, na = "–",
                                             range = "Tabelle1!A19:K23", col_names = FALSE)) %>%
  as.matrix() %>%
  {.[, c(1, 10:11)]} %>%
  addzero() %>%
  data.table::as.data.table()
names(Q_wshe) <- coln
Q_wshe <- data.table::melt(Q_wshe, id = "Kuerzel", variable.name = "nW") %>%
  mutate(selection = paste0(as.character(Kuerzel), as.character(nW)))

# --- 7. Hot water generation: Wg --------------------------------------------

# 7.1 Producer effort figure
coln <- c("Kuerzel", "1 bis 2", "3 und mehr")
E_wg <- suppressMessages(readxl::read_xlsx(waerme_path, na = "–",
                                           range = "Tabelle1!A28:E60", col_names = FALSE)) %>%
  as.matrix() %>%
  {.[, c(1, 4:5)]} %>%
  addzero() %>%
  data.table::as.data.table()
names(E_wg) <- coln
E_wg <- data.table::melt(E_wg, id = "Kuerzel", variable.name = "nW") %>%
  mutate(selection = paste0(as.character(Kuerzel), as.character(nW)))

# 7.2 Auxiliary energy requirement
coln <- c("Kuerzel", "1 bis 2", "3 und mehr")
Q_wghe <- suppressMessages(readxl::read_xlsx(waerme_path, na = "–",
                                             range = "Tabelle1!A28:K60", col_names = FALSE)) %>%
  as.matrix() %>%
  {.[, c(1, 10:11)]} %>%
  addzero() %>%
  data.table::as.data.table()
names(Q_wghe) <- coln
Q_wghe <- data.table::melt(Q_wghe, id = "Kuerzel", variable.name = "nW") %>%
  mutate(selection = paste0(as.character(Kuerzel), as.character(nW)))

# --- 8. Heating transfer: Hce ------------------------------------------------

# 8.1 Heat loss
coln <- c("Kuerzel", "value")
Q_hce <- suppressMessages(readxl::read_xlsx(waerme_path, na = "–",
                                            range = "Tabelle1!A65:E66", col_names = FALSE)) %>%
  as.matrix() %>%
  {.[, c(1, 5)]} %>%
  addzero() %>%
  data.table::as.data.table()
names(Q_hce) <- coln
# (keeps original selection construction using nonexistent nG -> NA if not present)
selection <- paste0(as.character(Q_hce$Kuerzel), as.character(Q_hce$nG))
Q_hce <- cbind(Q_hce, selection)

# 8.2 Auxiliary energy requirement
Q_hcehe <- suppressMessages(readxl::read_xlsx(waerme_path, na = "–",
                                              range = "Tabelle1!A65:K66", col_names = FALSE)) %>%
  as.matrix() %>%
  {.[, c(1, 10)]} %>%
  addzero() %>%
  data.table::as.data.table()
names(Q_hcehe) <- coln
selection <- paste0(as.character(Q_hcehe$Kuerzel), as.character(Q_hcehe$nG))
Q_hcehe <- cbind(Q_hcehe, selection)

# --- 9. Heat distribution: Hd ------------------------------------------------

# 9.1 Heat loss
coln <- c("Kuerzel", "1 bis 2", "3 bis 5", "6 und mehr")
Q_hd <- suppressMessages(readxl::read_xlsx(waerme_path, na = "–",
                                           range = "Tabelle1!A73:F78", col_names = FALSE)) %>%
  as.matrix() %>%
  {.[, c(1, 4:6)]} %>%
  addzero() %>%
  data.table::as.data.table()
names(Q_hd) <- coln
Q_hd <- data.table::melt(Q_hd, id = "Kuerzel", variable.name = "nG") %>%
  mutate(selection = paste0(as.character(Kuerzel), as.character(nG)))

# 9.2 Auxiliary energy requirement
coln <- c("Kuerzel", "1 bis 2", "3 und mehr")
Q_hdhe <- suppressMessages(readxl::read_xlsx(waerme_path, na = "–",
                                             range = "Tabelle1!A73:K78", col_names = FALSE)) %>%
  as.matrix() %>%
  {.[, c(1, 10:11)]} %>%
  addzero() %>%
  data.table::as.data.table()
names(Q_hdhe) <- coln
Q_hdhe <- data.table::melt(Q_hdhe, id = "Kuerzel", variable.name = "nW") %>%
  mutate(selection = paste0(as.character(Kuerzel), as.character(nW)))

# --- 10. Heat storage: Hs ----------------------------------------------------

# 10.1 Heat loss
coln <- c("Kuerzel", "1 bis 2", "3 und mehr")
Q_hs <- suppressMessages(readxl::read_xlsx(waerme_path, na = "–",
                                           range = "Tabelle1!A84:E85", col_names = FALSE)) %>%
  as.matrix() %>%
  {.[, c(1, 4:5)]} %>%
  addzero() %>%
  data.table::as.data.table()
names(Q_hs) <- coln
Q_hs <- data.table::melt(Q_hs, id = "Kuerzel", variable.name = "nW") %>%
  mutate(selection = paste0(as.character(Kuerzel), as.character(nW)))

# 10.2 Auxiliary energy requirement
coln <- c("Kuerzel", "1 bis 2", "3 und mehr")
Q_hshe <- suppressMessages(readxl::read_xlsx(waerme_path, na = "–",
                                              range = "Tabelle1!A84:K85", col_names = FALSE)) %>%
  as.matrix() %>%
  {.[, c(1, 10:11)]} %>%
  addzero() %>%
  data.table::as.data.table()
names(Q_hshe) <- coln
Q_hshe <- data.table::melt(Q_hshe, id = "Kuerzel", variable.name = "nW") %>%
  mutate(selection = paste0(as.character(Kuerzel), as.character(nW)))

# --- 11. Heat generation: Hg -------------------------------------------------

rown_hg <- suppressMessages(readxl::read_xlsx(waerme_path, na = "–",
                                              range = "Tabelle1!A90:A117", col_names = FALSE)) %>%
  as.matrix()
rown_hg <- rown_hg[, 1]
coln_hg <- c("1 bis 2", "3 und mehr")

# 11.1 Producer effort figure
coln <- c("Kuerzel", "1 bis 2", "3 und mehr")
E_hg <- suppressMessages(readxl::read_xlsx(waerme_path, na = "–",
                                           range = "Tabelle1!A90:E117", col_names = FALSE)) %>%
  as.matrix() %>%
  {.[, c(1, 4:5)]} %>%
  addzero() %>%
  data.table::as.data.table()
names(E_hg) <- coln
E_hg <- data.table::melt(E_hg, id = "Kuerzel", variable.name = "nW") %>%
  mutate(selection = paste0(as.character(Kuerzel), as.character(nW)))

# 11.2 Auxiliary energy requirement
coln <- c("Kuerzel", "1 bis 2", "3 und mehr")
Q_hghe <- suppressMessages(readxl::read_xlsx(waerme_path, na = "–",
                                             range = "Tabelle1!A90:K117", col_names = FALSE)) %>%
  as.matrix() %>%
  {.[, c(1, 10:11)]} %>%
  addzero() %>%
  data.table::as.data.table()
names(Q_hghe) <- coln
Q_hghe <- data.table::melt(Q_hghe, id = "Kuerzel", variable.name = "nW") %>%
  mutate(selection = paste0(as.character(Kuerzel), as.character(nW)))

# --- 12. Save intermediate results -------------------------------------------

setwd(user)
setwd("04 Intermediate Results")

rm("coln", "coln_hg", "coln_klima", "coln_u", "coln_kosten_et", "rown_hg", "selection")

save.image("02 Datentabellen.RData")

setwd(user)
setwd("03 R Code")




