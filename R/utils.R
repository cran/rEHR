#' Compresses a dataframe to make more efficient use of resources
#' 
#' Converts date variables in a dataframe to integers
#' Integers represent time in days from the supplied origin 
#' Converts specified numeric values to integer
#' This function is useful for keeping file sizes down and is used by the to_stata command to 
#' save to Stata files.
#' 
#' @export
#' 
#' @param dat a dataframe
#' @param origin ISO string representation of the dat of origin.  default is UNIX start date
#' @param format character: format of the date string.  Default is ISO standard
#' @param date_fields character vector of column names representing dates
#' @param integer_fields character vector of column names that should be integers
#' @return dataframe
compress <- function(dat, origin = "1970-01-01", format = "%Y-%m-%d",
                           date_fields = c("eventdate", "sysdate", "lcd", "uts", 
                                           "frd", "crd", "tod", "deathdate"),
                     integer_fields = c("yob", "practid")){
    date_to_int <- function(x){
        if(is(x, "character")) x <- as.Date(x, format = format)
        if(is(x, "Date")) as.integer(x - as.Date(origin))
    }
    message("compressing...")
    for(n in intersect(date_fields, names(dat))){
        dat[[n]] <- date_to_int(dat[[n]])
    }
    for(n in intersect(integer_fields, names(dat))){
        if(class(dat[[n]]) != "integer") dat[[n]] <- as.integer(dat[[n]])
    }
    dat
}
    
#' Compresses a dataframe and saves in stata format.  Options to save as Stata 12 or 13.
#' 
#' Automatically compresses data to reduce file size
#' 
#' Defaults to saving compressed dates to integer days from 1960-01-01
#' which is the standard in stata.
#' 
#' @export
#'  
#' @param dat dataframe
#' @param fname character string: filepath to save to
#' @param stata13 logical Save as Stata13 compatible format?
#' @param \dots arguments to be passed to compress
to_stata <- function(dat, fname, stata13 = FALSE, ...){
    if(stata13){
        readstata13::save.dta13(compress(dat, origin = "1960-01-01", ...), fname, compress = TRUE)
        message(sprintf("Dataframe %s exported to %s (Stata v13 compatable)", 
                        deparse(substitute(dat)), fname))
    } else {
        foreign::write.dta(compress(dat, origin = "1960-01-01", ...), fname)
        message(sprintf("Dataframe %s exported to %s (Stata v12 compatable)", 
                        deparse(substitute(dat)), fname))
        
    }
}

#' combines strings and vectors in a sensible way for select queries
#' 
#' This function is a variant of the sprintf function.
#' In the query, can be placed identifier tags which are a hash character followed by a number 
#' e.g. #1
#' The number in the tag reflects the position of the arguments after the query
#' The resut of evaluating that argument will then be inserted in place of the tag.
#' If the result of evaluating the argument is a vector of length 1, it is inserted as is.
#' If it is a vector of length > 1, it is wrapped in parentheses and comma separated.  
#' 
#' Note that this function is for help in constructing raw SQL queries and should not be used as an 
#' input to the \code{where} argument in \code{select_event} calls.
#' This is because these calls use translate_sql_ to translate from R code to SQL
#' 
#' @export
#' 
#' @param query a character string with identifier tags (#[number]) for selecting the argument in \dots
#' @param \dots optional arguments selected by the identifier tags
#' @examples
#' medcodes1 <- 1:5
#' practice <- 255
#' wrap_sql_query("eventdate >= STARTDATE & eventdate <= ENDDATE & medcode %in% #1 & 
#'    practice == #2", medcodes1, practice)
wrap_sql_query <- function(query, ...){
    items <- list(...)
    if(!length(items)) return(query)
    items <- lapply(items, function(x){
        if(length(x) > 1){
            paste("(", paste(x, collapse = ", "), ")")
        } else x
    })
    locations <- unique(unlist(str_extract_all(query, "#[0-9]+")))
    max_locations <- max(as.numeric(unlist(str_extract_all(locations, "[0-9]+"))))
    assert_that(length(items) == max_locations)
    items_dict <- list()
    for(l in 1:length(locations)){
        items_dict[[locations[l]]] <- items[[as.integer(str_extract(locations[l], "[0-9]+"))]]
    }
    for(n in names(items_dict)){
        query <- str_replace_all(query, n, items_dict[[n]])
    }
    query
}


#' Reads strings and expands sections wrapped in dotted parentheses
#' 
#' This is a kind of inverse of bquote
#'  
#' @param s a string
#' @param level integer sets the parent frame level for evaluation
#' @examples
#' a <- runif(10)
#' expand_string("The r code is .(a)")
#' @export
expand_string <- function(s, level = 3){
    e <- strsplit(s, "[[:space:]]+")[[1]]
    paste(lapply(e, 
                 function(x){
                     if(str_detect(x, "^\\.")){
                         eval(parse(text = str_match(x, "\\.(.+)")[2]),
                              envir = parent.frame(n = level))
                     } else x
                 }), collapse = " ")
}


#' converts date fields from ISO character string format to R Date format
#' 
#' Date fields are determined by the date-fields element in the .ehr definition.  Extra
#' date fields can be added to the extras argument or by setting `.ehr$date_fields`.
#' @export
#' 
#' @param dat a dataframe
#' @param extras = a character vector of extra columns to convert or NULL for no extras
#' @seealso
#' get_EHR_value
#' set_EHR_value
convert_dates <- function(dat, extras = NULL){
    f_dates <- intersect(c(extras, names(dat)), .ehr$date_fields)
    if(length(f_dates)){
        message("Converting date columns...")
        for(column in f_dates){
            if(!is(dat[[column]], "Date")){
                dat[[column]] <- as.Date(dat[[column]], origin = "1970-01-01")
            }
        }
    }
    dat
}


#' Exports to a variety of formats based on the file type argument
#' 
#' @export
#' @param x object to be exported
#' @param file character path to the file to be exported to 
#' @param \dots arguments to be passed to the export functions
#' 
#' File type is based on the file suffix and can be one of "txt", "csv", "rda", "dta".
#' dta files use foreign::write.dta.  
#' If a match is not found, the file is written to std.out
export_fn <- function(x, file, ...){
    file_type <- str_match(file, "\\.([a-zA-Z]+$)")[,2]
    switch(file_type, 
           txt = write.table(x, file = file, ...),
           csv = write.csv(x, file = file, ...),
           rda = save(x, file = file, ...),
           dta = foreign::write.dta(as.data.frame(x), file = file, ...),
           write.table(x, file = "", ...))
}


#' Exports flat files from the database.  One file per practice
#' 
#' @export
#'  
#' @param db a database connection
#' @param table character the table to be exported
#' @param practice_table the table that the practice definitions can be found
#' @param out_dir a directory to output to.  This will be created if it does not already exist
#' @param file_type the type of file to be saved. This can be one of "txt", "csv", "rda", "dta".
#' @param \dots arguments to be passed to export_fn
#'  
#' Defaults to exporting consultation tables for use by \code{match_on_index()}.  the full path 
#' to \code{out_dir} will be created if it does not already exist. 
#' @seealso
#' match_on_index
#' export_fn
flat_files <- function(db, table = "Consultation", practice_table = "Practice", 
                       out_dir, file_type = c("txt", "csv", "rda", "dta"), ...){
    dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
    file_type <- match.arg(file_type)    
    practices <- unique(select_events(db, practice_table)[[ .ehr$practice_id]])
    for (practice in practices){
        tab <- select_events(db, table, where = ".(.ehr$practice_id) == .(practice)")
        fname <- file.path(out_dir, paste0("ehr_", table, 
                                           str_pad(practice, width = 3, 
                                                   pad = 0), ".", file_type))
        message("exporting to ", fname, "...")
        export_fn(tab, file = fname, ...)
    }
    message("Done exporting.")
}