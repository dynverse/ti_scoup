#!/usr/local/bin/Rscript

task <- dyncli::main()

library(jsonlite)
library(readr)
library(dplyr)
library(purrr)

#   ____________________________________________________________________________
#   Load data                                                               ####

expression <- as.matrix(task$expression)
params <- task$params
groups_id <- task$priors$groups_id
start_id <- task$priors$start_id
end_n <- task$priors$end_n

#   ____________________________________________________________________________
#   Infer trajectory                                                        ####

# if the dataset is cyclic, pretend it isn't
if (end_n == 0) {
  end_n <- 1
}

start_cell <- sample(start_id, 1)

# figure out indices of starting population
# from the groups_id and the start_cell
start_ix <- groups_id %>%
  filter(cell_id %in% start_cell) %>%
  select(group_id) %>%
  left_join(groups_id, by = "group_id") %>%
  .$cell_id

# create distribution on starting population
vars <- apply(expression[start_ix,, drop = FALSE], 2, stats::var)
vars[is.na(vars | vars == 0)] <- diff(range(expression)) * 1e-3
means <- apply(expression[start_ix,, drop = FALSE], 2, mean)
distr_df <- data.frame(i = seq_along(vars) - 1, means, vars)

# write data to files
utils::write.table(t(expression), file = "data", sep = "\t", row.names = FALSE, col.names = FALSE)
utils::write.table(distr_df, file = "init", sep = "\t", row.names = FALSE, col.names = FALSE)

# TIMING: done with preproc
checkpoints <- list(method_afterpreproc = as.numeric(Sys.time()))

# execute sp
cmd <- glue::glue("/SCOUP/sp data init time_sp dimred {ncol(expression)} {nrow(expression)} {params$ndim}")
cat(cmd, "\n", sep = "")
system(cmd)

# execute scoup
cmd <- paste0(
  "/SCOUP/scoup data init time_sp gpara cpara ll ",
  ncol(expression), " ", nrow(expression),
  " -k ", end_n,
  " -m ", params$max_ite1,
  " -M ", params$max_ite2,
  " -a ", params$alpha[1],
  " -A ", params$alpha[2],
  " -t ", params$t[1],
  " -T ", params$t[2],
  " -s ", params$sigma_squared_min,
  " -e ", params$thresh
)
cat(cmd, "\n", sep = "")
system(cmd)

# read dimred
dimred <- utils::read.table("dimred", col.names = c("i", paste0("Comp", seq_len(params$ndim))))

# last line is root node
root <- dimred[nrow(dimred),-1,drop=F]
dimred <- as.matrix(dimred[-nrow(dimred),-1])
rownames(dimred) <- rownames(expression)

# read cell params
cpara <- utils::read.table("cpara", col.names = c("time", paste0("M", seq_len(end_n))))
rownames(cpara) <- rownames(expression)

# loglik
ll <- utils::read.table("ll")[[1]]

# TIMING: done with method
checkpoints$method_aftermethod <- as.numeric(Sys.time())

if (any(is.na(ll))) {
  stop("SCOUP returned NaNs", call. = FALSE)
}

pseudotime <- cpara %>% {set_names(.$time, rownames(.))}
esp <- cpara %>% select(-time) %>% tibble::rownames_to_column("cell_id")

#   ____________________________________________________________________________
#   Save output                                                             ####

output <- dynwrap::wrap_data(cell_ids = names(pseudotime)) %>%
  dynwrap::add_end_state_probabilities(
    end_state_probabilities = esp,
    pseudotime = pseudotime,
    do_scale_minmax = TRUE
  ) %>%
  dynwrap::add_dimred(dimred = dimred) %>%
  dynwrap::add_timings(timings = checkpoints)

output %>% dyncli::write_output(task$output)
