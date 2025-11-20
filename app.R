# app.R
# Minimal, robust Shiny runner for the EBJ pipeline (with choosers + histogram)
# Hardened for missing-imputation paths

# ----------------------- Packages -----------------------
pkgs <- c("shiny","DT","tools","haven","dplyr","readxl")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install)) install.packages(to_install, repos = "https://cloud.r-project.org")
lapply(pkgs, library, character.only = TRUE)

# ----------------------- Helpers ------------------------
# Safe normalize (Windows paths OK)
norm <- function(p) normalizePath(p, winslash = "/", mustWork = FALSE)

# Detect absolute path (Windows or POSIX)
is_abs_path <- function(p) {
  if (is.null(p) || !nzchar(p)) return(FALSE)
  grepl("^([A-Za-z]:)?[\\/]", p) || grepl("^\\\\\\\\", p) # UNC
}

# Return absolute path: if already absolute -> normalize; else relative to base
abs_or_base <- function(p, base) {
  if (is_abs_path(p)) norm(p) else norm(file.path(base, p))
}

# Make a path relative to base if possible (for display in the UI inputs)
rel_to_base <- function(path_abs, base) {
  path_abs <- norm(path_abs); base <- norm(base)
  base_pat <- paste0("^", gsub("([\\^\\$\\.|()\\[\\]{}+?*])","\\\\\\1", base), "/")
  if (startsWith(tolower(path_abs), paste0(tolower(base), "/"))) sub(base_pat, "", path_abs) else path_abs
}

required_subdirs <- c(
  "01 Raw","02 Parameter","03 R Code","04 Intermediate Results","05 Final Results"
)

required_scripts <- c(
  "00 Master File.R"            = "03 R Code/00_Master_File.R",
  "01_WuW_Data.R"              = "03 R Code/01_WuW_Data.R",
  "02_Individual_Parameters.R" = "03 R Code/02_Individual_Parameters.R",
  "03_System_Technology.R"     = "03 R Code/03_System_Technology.R",
  "04_Building_Balance_Sheet.R"= "03 R Code/04_Building_Balance_Sheet.R",
  "05_System_Balance_Sheet.R"  = "03 R Code/05_System_Balance_Sheet.R"
)

# Files your scripts expect (relative to project root by default)
default_data_files <- list(
  file_building = "01 Raw/ariadne_panel1_buildingchars_eng_update24.dta",
  file_refurb   = "01 Raw/ariadne_panel1_experiments_eng_update24.dta",
  rules         = "02 Parameter/Fehlende Werte.xlsx",
  u_werte_all   = "02 Parameter/U Werte Baukonstruktion_update.xlsx",
  u_werte_f     = "02 Parameter/U und G Werte Fenster_update.xlsx",
  klima_file    = "02 Parameter/Klimakoeffizienten.xlsx",
  kosten_file   = "02 Parameter/Kosten pro Energietraeger.xlsx",
  waerme_file   = "02 Parameter/Waermekennwerte Anlagentechnik.xlsx"
)

# ----------------------- UI -----------------------------
# Text input + Browse button
fileRow <- function(inputId, label, value, title="Select a file") {
  fluidRow(
    column(8, textInput(inputId, label, value = value)),
    column(4, div(style="margin-top:27px",
                  shinyFiles::shinyFilesButton(
                    id = paste0("browse_", inputId),
                    label = "Browse…",
                    title = title,
                    multiple = FALSE
                  )))
  )
}

ui <- fluidPage(
  titlePanel("Final Energy Demand Calculator 🔥"),
  sidebarLayout(
    sidebarPanel(
      width = 4,
      textInput("base_dir", "Project root folder", value = norm(getwd())),
      checkboxInput("run_missing_imputation", "Run missing imputation (01_WuW_Data)", FALSE),
      hr(),
      selectInput("wave", "Data wave", choices = c("Wave 1" = "panel1", "Wave 2" = "panel2"), selected = "panel1"),
      helpText("Choosing a wave auto-selects the two .dta files from '01 Raw'."),
      hr(),
      strong("Parameter files"),
      helpText("Only Excel files (.xlsx, .xls) are allowed."),
      textInput("rules",         "Missing rules .xlsx", default_data_files$rules),
      textInput("u_werte_all",   "U-Werte Baukonstruktion .xlsx", default_data_files$u_werte_all),
      textInput("u_werte_f",     "U/G-Werte Fenster .xlsx", default_data_files$u_werte_f),
      textInput("klima_file",     "Klimakoeffizienten .xlsx", default_data_files$klima_file),
      textInput("kosten_file",    "Kosten pro Energietraeger .xlsx", default_data_files$kosten_file),
      textInput("waerme_file",    "Waermekennwerte Anlagentechnik .xlsx", default_data_files$waerme_file),
      hr(),
      actionButton("validate", "Validate Setup"),
      actionButton("run", "Run Pipeline", class = "btn-primary"),
      br(), br(),
      downloadButton("download_csv", "Download Result as CSV"),
      br(), br(),
      helpText("Result file is written to '05 Final Results/Result_File.dta'")
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Status & Logs",
                 br(),
                 verbatimTextOutput("status"),
                 tags$hr(),
                 pre(style="max-height: 300px; overflow-y: auto; border:1px solid #ddd; padding:10px;",
                     textOutput("log"))
        ),
        tabPanel("Preview Result",
                 br(),
                 DTOutput("preview")
        ),
        tabPanel("Histogram",
                 br(),
                 fluidRow(
                   column(6, sliderInput("hist_bins", "Number of bins", min = 10, max = 150, value = 50, step = 5)),
                   column(6, checkboxInput("hist_drop_na", "Drop non-finite values (NA/Inf)", TRUE))
                 ),
                 plotOutput("hist_ebj", height = "420px"),
                 uiOutput("hist_info")
        )
      )
    )
  )
)

# ----------------------- SERVER -------------------------
server <- function(input, output, session) {
  
  log_txt <- reactiveVal("")
  append_log <- function(...) {
    msg <- paste(..., collapse = " ")
    log_txt(paste0(log_txt(), if (nzchar(log_txt())) "\n" else "", msg))
  }
  output$log <- renderText(log_txt())
  
  status_txt <- reactiveVal("Idle")
  output$status <- renderText(status_txt())
  
  # Bump to force re-read of result after pipeline run
  result_version <- reactiveVal(0L)
  
  # ----- Auto-detect project root (on load) -----
  observe({
    current <- norm(input$base_dir)
    # Try to auto-detect by locating the known subfolders relative to getwd()
    wd <- norm(getwd())
    candidates <- unique(c(wd,
                           norm(file.path(wd, "..")),
                           norm(dirname(wd))))
    has_signature <- function(dir_path) {
      all(file.exists(file.path(dir_path, required_subdirs)))
    }
    detected <- NA_character_
    for (cand in candidates) {
      if (dir.exists(cand) && has_signature(cand)) { detected <- cand; break }
    }
    if (is.na(detected)) {
      # Fallback: if this script sits in project root, use it
      if (has_signature(wd)) detected <- wd
    }
    if (!is.na(detected) && !identical(current, detected)) {
      updateTextInput(session, "base_dir", value = detected)
    }
  })

  # File browser removed for reliability; use the text inputs above to specify files.
  
  # ---- Shared: load and cache Result file (if present) ----
  result_df <- reactive({
    # dependency so this re-computes after each successful run
    result_version()
    base <- norm(input$base_dir)
    res_path <- file.path(base, "05 Final Results", "Result_File.dta")
    if (!file.exists(res_path)) return(NULL)
    df <- tryCatch(haven::read_dta(res_path), error = function(e) NULL)
    if (is.null(df)) return(NULL)
    as.data.frame(df)
  })
  
  # Validate structure
  observeEvent(input$validate, {
    log_txt("")  # clear
    base <- norm(input$base_dir)
    status_txt("Validating folder structure...")
    ok <- TRUE
    
    if (!dir.exists(base)) { append_log("✗ Base folder does not exist:", base); ok <- FALSE }
    for (d in required_subdirs) {
      p <- file.path(base, d)
      if (!dir.exists(p)) { append_log(paste("✗ Missing subfolder:", d)); ok <- FALSE } else {
        append_log(paste("✓ Found subfolder:", d))
      }
    }
    for (nm in names(required_scripts)) {
      p <- file.path(base, required_scripts[[nm]])
      if (!file.exists(p)) { append_log(paste("✗ Missing script:", required_scripts[[nm]])); ok <- FALSE } else {
        append_log(paste("✓ Found script:", required_scripts[[nm]]))
      }
    }
    # Check files (absolute allowed)
    # Check parameter files only (entered via UI)
    for (nm in c("rules","u_werte_all","u_werte_f","klima_file","kosten_file","waerme_file")) {
      val <- if (is.null(input[[nm]])) "" else input[[nm]]
      if (nzchar(val) && !grepl("\\.(xlsx|xls)$", val, ignore.case = TRUE)) {
        append_log(paste("✗ Invalid file type for", nm, "(must be .xlsx or .xls):", val)); ok <- FALSE
        next
      }
      p <- abs_or_base(val, base)
      if (!nzchar(val) || !file.exists(p)) { append_log(paste("• Note: Not found yet (will be required at runtime):", val)) }
      else { append_log(paste("✓ Found parameter file:", val)) }
    }

    # Derive data files from wave selection and check existence
    wave <- if (identical(input$wave, "panel2")) "panel2" else "panel1"
    # Wave 1 has "update24" suffix, Wave 2 does not
    if (wave == "panel1") {
      file_building <- file.path("01 Raw", sprintf("ariadne_%s_buildingchars_eng_update24.dta", wave))
      file_refurb   <- file.path("01 Raw", sprintf("ariadne_%s_experiments_eng_update24.dta",   wave))
    } else {
      file_building <- file.path("01 Raw", sprintf("ariadne_%s_buildingchars_eng.dta", wave))
      file_refurb   <- file.path("01 Raw", sprintf("ariadne_%s_experiments_eng.dta",   wave))
    }
    append_log("Wave:", wave)
    if (!file.exists(file.path(base, file_building))) { append_log(paste("• Note: Data file not found yet:", file_building)) } else { append_log(paste("✓ Found data file:", file_building)) }
    if (!file.exists(file.path(base, file_refurb)))   { append_log(paste("• Note: Data file not found yet:", file_refurb)) }   else { append_log(paste("✓ Found data file:", file_refurb)) }
    
    if (ok) status_txt("Validation OK ✅") else status_txt("Validation found issues ⚠️ — see log")
  })
  
  # Run pipeline
  observeEvent(input$run, {
    log_txt("")  # clear
    status_txt("Running pipeline...")
    base <- norm(input$base_dir)
    
    if (!dir.exists(base)) {
      status_txt("Base folder not found."); append_log("Stop: base folder not found."); return()
    }
    
    # Local .zip package installation removed; rely on CRAN installation below
    
    # --- Install + load runtime packages needed by your scripts ---
    pkgs_needed <- c(
      "dplyr","data.table","readxl","haven","openxlsx","labelled",
      "foreign","stringr","tidyverse","Rcpp","magrittr"
    )
    to_install2 <- pkgs_needed[!pkgs_needed %in% installed.packages()[, "Package"]]
    if (length(to_install2)) install.packages(to_install2, repos = "https://cloud.r-project.org")
    lapply(pkgs_needed, library, character.only = TRUE)
    
    # Preflight when missing imputation is requested
    if (isTRUE(input$run_missing_imputation)) {
      rules_path <- abs_or_base(input$rules, base)
      uw_all     <- abs_or_base(input$u_werte_all, base)
      uw_f       <- abs_or_base(input$u_werte_f, base)
      append_log("Preflight (missing-imputation):")
      append_log(" - rules:", rules_path)
      append_log(" - u_werte_all:", uw_all)
      append_log(" - u_werte_f:", uw_f)
      
      missing_files <- c(!file.exists(rules_path), !file.exists(uw_all), !file.exists(uw_f))
      if (any(missing_files)) {
        status_txt("Run failed ❌ — see logs below")
        if (!file.exists(rules_path)) append_log("ERROR: Rules .xlsx not found at:", rules_path)
        if (!file.exists(uw_all))     append_log("ERROR: U-Werte Baukonstruktion .xlsx not found at:", uw_all)
        if (!file.exists(uw_f))       append_log("ERROR: U/G-Werte Fenster .xlsx not found at:", uw_f)
        return()
      }
      
      # Try opening sheets just to ensure the files are readable
      tryCatch({
        readxl::excel_sheets(rules_path)
        readxl::excel_sheets(uw_all)
        readxl::excel_sheets(uw_f)
        append_log("Preflight OK: Excel files are readable.")
      }, error = function(e) {
        append_log("ERROR: Could not open one of the Excel files:", conditionMessage(e))
        status_txt("Run failed ❌ — see logs below")
        return()
      })
    }
    
    # Create a clean environment for sourcing the scripts
    env <- new.env(parent = .GlobalEnv)
    env$`%>%` <- get("%>%", asNamespace("magrittr"))
    env$load <- function(file, ...) base::load(file = file, envir = env, ...)
    
    # Expose key variables your scripts expect
    env$user <- base
    env$run_missing_imputation  <- isTRUE(input$run_missing_imputation)
    env$run_retrofit_imputation <- FALSE
    
    # Important: pass PARAMETER FILES as absolute paths (works with or without setwd())
    env$rules       <- abs_or_base(input$rules, base)
    env$u_werte_all <- abs_or_base(input$u_werte_all, base)
    env$u_werte_f   <- abs_or_base(input$u_werte_f, base)
    env$klima_file  <- abs_or_base(input$klima_file, base)
    env$kosten_file <- abs_or_base(input$kosten_file, base)
    env$waerme_file <- abs_or_base(input$waerme_file, base)
    
    # Data files: derive from wave selection (relative paths from project root)
    wave <- if (identical(input$wave, "panel2")) "panel2" else "panel1"
    # Wave 1 has "update24" suffix, Wave 2 does not
    if (wave == "panel1") {
      env$file_building <- file.path("01 Raw", sprintf("ariadne_%s_buildingchars_eng_update24.dta", wave))
      env$file_refurb   <- file.path("01 Raw", sprintf("ariadne_%s_experiments_eng_update24.dta",   wave))
    } else {
      env$file_building <- file.path("01 Raw", sprintf("ariadne_%s_buildingchars_eng.dta", wave))
      env$file_refurb   <- file.path("01 Raw", sprintf("ariadne_%s_experiments_eng.dta",   wave))
    }
    
    # Safety: make sure the working dir starts at base
    owd <- getwd()
    on.exit(setwd(owd), add = TRUE)
    setwd(base)
    
    # Capture console output
    tmp_log <- tempfile(fileext = ".txt")
    sink(tmp_log, split = TRUE)
    on.exit({ sink(NULL) }, add = TRUE)
    
    append_log(">>> Starting EBJ pipeline ...")
    append_log("Base:", base)
    append_log("Missing imputation:", env$run_missing_imputation)
    
    # Execute scripts in order
    run_script <- function(path) {
      append_log(paste("Sourcing:", path))
      script_env <- new.env(parent = env)
      # ensure config present even if script rm()s
      script_env$user <- env$user
      script_env$run_missing_imputation  <- env$run_missing_imputation
      script_env$run_retrofit_imputation <- env$run_retrofit_imputation
      script_env$file_building <- env$file_building
      script_env$file_refurb   <- env$file_refurb
      script_env$rules         <- env$rules         # absolute
      script_env$u_werte_all   <- env$u_werte_all   # absolute
      script_env$u_werte_f     <- env$u_werte_f     # absolute
      sys.source(path, envir = script_env, keep.source = FALSE, chdir = FALSE)
      # propagate objects back
      objs <- ls(script_env, all.names = TRUE)
      if (length(objs)) {
        for (nm in objs) assign(nm, get(nm, envir = script_env), envir = env)
      }
    }
    
    ok <- TRUE
    tryCatch({
      run_script(file.path(base, required_scripts[["01_WuW_Data.R"]]))
      run_script(file.path(base, required_scripts[["02_Individual_Parameters.R"]]))
      run_script(file.path(base, required_scripts[["03_System_Technology.R"]]))
      run_script(file.path(base, required_scripts[["04_Building_Balance_Sheet.R"]]))
      run_script(file.path(base, required_scripts[["05_System_Balance_Sheet.R"]]))
    }, error = function(e) {
      ok <<- FALSE
      append_log("ERROR:", conditionMessage(e))
      status_txt("Run failed ❌ — see logs below")
    })
    
    sink(NULL) # flush
    if (file.exists(tmp_log)) {
      append_log(readChar(tmp_log, file.info(tmp_log)$size))
    }
    
    if (ok) {
      status_txt("Run completed ✅")
      res_path <- file.path(base, "05 Final Results", "Result_File.dta")
      if (file.exists(res_path)) {
        append_log("Result created:", res_path)
        # Trigger UI to refresh preview and histogram
        result_version(result_version() + 1L)
      } else {
        append_log("Warning: Result_File.dta not found in '05 Final Results'.")
      }
    }
  })
  
  # Files tab removed per request
  
  # Preview
  output$preview <- renderDT({
    df <- result_df()
    if (is.null(df)) return(DT::datatable(data.frame(Message = "Result_File.dta not found yet.")))
    DT::datatable(head(df, 500), options = list(pageLength = 25))
  })
  
  # Histogram of ebj
  output$hist_ebj <- renderPlot({
    df <- result_df()
    if (is.null(df)) return(invisible())
    
    cn <- names(df)
    ebj_name <- cn[which(tolower(cn) == "ebj")]
    if (length(ebj_name) == 0) ebj_name <- cn[grepl("^ebj$", cn, ignore.case = TRUE)]
    if (length(ebj_name) == 0) return(invisible())
    
    x <- suppressWarnings(as.numeric(df[[ebj_name[1]]]))
    if (isTRUE(input$hist_drop_na)) x <- x[is.finite(x)]
    if (!length(x)) return(invisible())
    
    bins <- if (is.null(input$hist_bins)) 50L else as.integer(input$hist_bins)
    bins <- max(10L, min(150L, bins))
    
    hist(x, breaks = bins, main = paste("Histogram of", ebj_name[1]),
         xlab = ebj_name[1], ylab = "Count")
  })
  
  output$hist_info <- renderUI({
    df <- result_df()
    if (is.null(df)) return(NULL)
    cn <- names(df)
    ebj_name <- cn[which(tolower(cn) == "ebj")]
    if (length(ebj_name) == 0) ebj_name <- cn[grepl("^ebj$", cn, ignore.case = TRUE)]
    if (length(ebj_name) == 0) {
      return(HTML("<em>Column <code>ebj</code> not found in the result.</em>"))
    }
    x <- suppressWarnings(as.numeric(df[[ebj_name[1]]]))
    x2 <- x[is.finite(x)]
    if (!length(x2)) return(HTML("<em>No finite numeric values in <code>ebj</code> to plot.</em>"))
    rng <- range(x2)
    p <- sprintf("N=%d, min=%.3f, p50=%.3f, mean=%.3f, max=%.3f",
                 length(x2), rng[1], stats::median(x2), mean(x2), rng[2])
    tags$p(strong("Summary: "), p)
  })
  
  # Download as CSV
  output$download_csv <- downloadHandler(
    filename = function() paste0("Result_File.csv"),
    content = function(file) {
      df <- result_df()
      if (is.null(df)) stop("Result file not found.")
      utils::write.csv(df, file, row.names = FALSE, fileEncoding = "UTF-8")
    }
  )
}

shinyApp(ui, server)


