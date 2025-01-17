# vim: set ts=4 sts=0 sw=4 si fenc=utf-8 et:
# vim: set fdm=marker fmr={{{,}}} fdl=0 foldcolumn=4:
# Authors:     TS
# Maintainers: TS
# Copyright:   2021, HRDAG, GPL v2 or later
# =========================================

pacman::p_load(
    argparse,
    arrow,
    digest,
    dplyr,
    purrr,
    stringr
)

parser <- ArgumentParser()
parser$add_argument("--minutes")
parser$add_argument("--pagetypes")
parser$add_argument("--output")
args <- parser$parse_args()

pad_num <- function(num) str_pad(num, width=4, side="left", pad="0")

mins <- read_parquet(args$minutes)
labs <- read_parquet(args$pagetypes)

docids <- labs %>%
    arrange(fileid, pageno) %>%
    mutate(newdoc = pageno == 1 | pagetype != "continuation") %>%
    group_by(fileid) %>%
    mutate(docseqid = cumsum(newdoc)) %>%
    group_by(fileid, docseqid) %>%
    mutate(hashargs = paste0(fileid, ".", pad_num(pageno), collapse=".")) %>%
    mutate(docid = map_chr(hashargs, digest, algo="sha1", serialize=FALSE),
           docid = str_sub(docid, 1, 8)) %>%
    mutate(doctype = if_else(pageno == min(pageno), pagetype, NA_character_),
           doctype = max(doctype, na.rm=TRUE)) %>%
    ungroup %>%
    select(fileid, pageno, docid, doctype)

out <- mins %>%
    select(fileid, starts_with("f_"), pageno, text) %>%
    inner_join(docids, by=c("fileid", "pageno"))

stopifnot(nrow(out) == nrow(mins))

write_parquet(out, args$output)

# done.
