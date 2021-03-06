% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/matching.R
\name{get_matches}
\alias{get_matches}
\title{Find matched controls for a set of cases}
\usage{
get_matches(cases, control_pool, n_controls, match_vars, extra_vars,
  extra_conditions = NULL, cores = 1, track = TRUE,
  tracker = function(case_num) ".", method = c("incidence_density",
  "exact"), diagnosis_date = NULL)
}
\arguments{
\item{cases}{dataframe of cases}

\item{control_pool}{dataframe of potential controls to be used for matching}

\item{n_controls}{number of controls to match to each case}

\item{match_vars}{character vector of variables in the dataframes to be used to perform the 
matching}

\item{extra_vars}{character vector of other variables to be used in the matching to define other
conditions}

\item{extra_conditions}{a character vector of length 1 defining further restrictions on matching}

\item{cores}{number of cpu cores to be used by multicore (windows users should leave set to 1)}

\item{track}{logical should a dot be printed to std.out for each case?}

\item{tracker}{function to track progress of the function (See details)}

\item{method}{The method of selection of controls (see details)}

\item{diagnosis_date}{character the name of the variable in the cases and control_pool datasets
containing the date of diagnosis (or other event to base the IDM method on).  If there is no
diagnosis date for a patient, this should be represented by NA}
}
\description{
This function will provide a set of matched controls for a given set of cases.
}
\details{
Setting method to "exact" means that the matched controls are removed from the control pool
after each case has been matched.  This makes this method not thread safe and so will only 
run on a single core (and more slowly).
Setting method to "incidence_density" is thread safe as the same controls can be used for more than one case.
See Richardson (2004) Occup Environ Med 2004;61:e59 doi:10.1136/oem.2004.014472 for a description 
of IDS matching.  Also see the introduction vignette.
The tracker variable allows for different outputs to track the progress of the function.
This is currently set to ouput a dot for every case matched.  A function can be added to the 
argument For a more verbose tracking, e.g. to track number of cases, 
set \code{tracker = function() paste0(case_num, ",")}
}

