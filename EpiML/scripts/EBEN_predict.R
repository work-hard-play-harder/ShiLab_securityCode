library('EBEN')

workspace <- '/Users/jchen67/Experiment/ShiLab_securityCode/EpiMap/upload_data/userid_1/jobid_1'
x_filename <- 'bc_x.txt'

args <- commandArgs(trailingOnly = TRUE)
workspace <- args[1]
model_dir <- args[2]
x_filename <- args[3]
main_filename <- 'EBEN.main_result.txt'
epis_filename <- 'EBEN.epis_result.txt'
hyperparams_filename <- 'EBEN.blup_full_hyperparams.txt'

cat('EBEN_predict parameters:', '\n')
cat('\tworkspace:', workspace, '\n')
cat('\tmodel_dir:', model_dir, '\n')
cat('\tx_filename:', x_filename, '\n')
cat('\tmain_filename:', main_filename, '\n')
cat('\tepis_filename:', epis_filename, '\n')
cat('\tintercept_filename:', hyperparams_filename, '\n')

cat('read data', '\n')
x <- read.table(
  file = file.path(workspace, x_filename),
  header = TRUE,
  check.names = FALSE,
  row.names = 1
)
sprintf('x size: (%d, %d)', nrow(x), ncol(x))

main_effect <-
  read.table(file = file.path(workspace, main_filename),
             header = T,
             sep = '\t',
             check.names = FALSE)
sprintf('main_effect size: (%d, %d)',
        nrow(main_effect),
        ncol(main_effect))

epis_effect <-
  read.table(file = file.path(workspace, epis_filename),
             header = T,
             sep = '\t',
             check.names = FALSE)
sprintf('epis_effect size: (%d, %d)',
        nrow(epis_effect),
        ncol(epis_effect))

hyperparams <-
  read.table(file = file.path(workspace, hyperparams_filename),
             header = TRUE)
sprintf('hyperparams size: (%d, %d)', nrow(hyperparams), ncol(hyperparams))
intercept<-hyperparams$Intercept

x <- t(x)
x11 <- matrix(as.numeric(x), nrow(x))

cat('Filter the miRNA data with more than 20% missing data', '\n')
x1 <- NULL
x1_rownames <- NULL
for (i in 1:nrow(x11)) {
  if (sum(as.numeric(x11[i, ]) != 0)) {
    x1 <- rbind(x1, x[i, ])
    x1_rownames <- c(x1_rownames, rownames(x)[i])
  }
}
rownames(x1) <- x1_rownames

x2 <- NULL
x2_rownames <- NULL
criteria <- trunc((ncol(x1) - 1) * 0.8)
for (i in 1:nrow(x1)) {
  if (sum(as.numeric(x1[i, (2:ncol(x1))]) != 0) > criteria) {
    x2 <- rbind(x2, x1[i, ])
    x2_rownames <- c(x2_rownames, x1_rownames[i])
  }
}
rownames(x2) <- x2_rownames
colnames(x2) <- colnames(x)

cat('Quantile normalization', '\n')
x3 <- x2
for (sl in 1:nrow(x3)) {
  mat = matrix(as.numeric(x3[sl, ]), 1)
  mat = t(apply(mat, 1, rank, ties.method = "average"))
  mat = qnorm(mat / (ncol(x3) + 1))
  x3[sl, ] = mat
}
rm(sl, mat)

cat('predict based on main epistatic effects', '\n')
x3 <- t(x3)
y_main_predict = x3[, main_effect[, 1]] %*% matrix(main_effect[, 2], ncol = 1)
Epis_geno = x3[, epis_effect[, 1], drop = F] * x3[, epis_effect[, 2], drop = F]
y_epis_predict = Epis_geno %*% matrix(epis_effect[, 3], ncol = 1)

y_predict = intercept + y_main_predict + y_epis_predict

y_predict <- data.frame(Samples = row.names(y_predict), y_predict)
write.table(
  y_predict,
  file = file.path(workspace, 'EBEN_predict.txt'),
  quote = F,
  sep = '\t',
  row.names = F,
  col.names = T
)

cat('Done!')
