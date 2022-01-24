library(tidyverse)
library(lubridate)
library(stringr)

update_data <- FALSE

if(update_data) {
  library(reticulate)
  use_condaenv('base')
  py_run_file('./scrape/scrapeEvents.py')
  py_run_file('./scrape/scrapeAthletes.py')
  py_run_file('./scrape/scrapeResults.py')
}

########## reading in files ###########

results_files <- list.files('./raw_data/results/', full.names = TRUE)
results_list <- lapply(results_files, read_csv, show_col_types = FALSE, num_threads = 36)
events_dirty <- read_csv('./raw_data/events.csv', show_col_types = FALSE)
athletes_dirty <- read_csv('./raw_data/athletes.csv', show_col_types = FALSE)

################ cleaning athletes #####################

# there are many athletes that have the multiple rows
# with different or no middle name or extension.
# grouping by lastname, firstname, nation, birthday
# gives 44 matches. I have reviewed all, and can say
# these are real matches.
#

# manual overrides for known errors
athletes_dirty[athletes_dirty$name == 'ALWINE Meredith',]$born = 'Jun 08, 1998'


results_names_dirty <- results_list %>%
  lapply(function(df) df[c('name', 'nation', 'born', 'cat')]) %>%
  bind_rows() %>%
  filter(
    str_length(nation) == 3
  ) %>%
  mutate(
    gender = if_else(str_detect(cat, 'Women'), 'W', 'M')
  ) %>%
  select(
    -cat
  ) %>%
  unique()

athletes <- athletes_dirty %>%
  mutate(
    nation = country
  ) %>%
  bind_rows(results_names_dirty) %>%
  distinct() %>%
  mutate(
    birthday = as_date(born, format = '%b %d, %Y', tz = "GMT")
  ) %>%
  mutate(names_split = name) %>%
  separate(col = names_split, into = c('last', 'first'), sep = ' ') %>% # separate names
  group_by(birthday, gender, last, first) %>% # group
  summarize(matches = length(name), name = toString(name), nations = toString(nation)) %>% # matching names sep by comma
  ungroup() %>%
  separate(col = name, into = c('name', 'name_alt'), sep = ', ') %>% # split alt names by comma
  mutate( # remove name_alt if not different than name, remove duplicate nations
    name_alt = ifelse(name == name_alt, NA, name_alt),
    nations = sapply(str_split(nations, ', '), function(x) toString(unique(x)))
    ) %>%
  rowid_to_column('athlete_id') %>%
  select( # final order
    athlete_id, name, name_alt, birthday, gender, nations
  ) %>% suppressWarnings()

#################### the cleaning function for results ########################

clean_results <- function(df) {
  # This function cleans an event result dataframe

  # fix for small events where there are no groups. shift columns left and set group as A.
  if((str_length(df$group)[1] > 1) && (sum(!is.na(df$lift4)) == 0 )) {
    df[7:10] <- df[6:9]
    df$group <- 'A'
  }

  df %>%
    filter(
      str_length(nation) == 3,
      str_length(group) == 1
    ) %>%
    arrange(desc(event_id)) %>%
    distinct() %>%
    replace_na( # '---' denotes 0/3 lifts, '', means no attempt/forfeit, set to na
      list('---', '')
    ) %>%
    mutate(
      dq = (rank == 'DSQ'), # total rank is 'DSQ' if disqualified, usually due to testing positive for PEDs
      birthday = as_date(born, format = '%b %d, %Y', tz = "GMT"), # convert to date
      across( # fix spaces between '-' and number
        c(rank, bw, lift1, lift2, lift3),
        str_remove_all,
        pattern = ' '
      ),
      across( # convert to numeric
        c(bw, lift1, lift2, lift3),
        as.numeric
      ),
      across( # convert to int
        c(rank, event_id, old_classes, dq),
        as.integer
      ),
      category = str_replace(cat, 'kg', ' kg ')
    ) %>%
    pivot_wider( # pivot lifts by section
      id_cols = c(name, dq, nation, birthday, bw, group, category, event_id, old_classes),
      names_from = sec,
      names_glue = '{sec}_{.value}',
      values_from = c(lift1, lift2, lift3, rank),
      values_fn = function(x) x[1] # if multiple entries select first
    ) %>%
    rename_all(tolower) %>%
    left_join( # join athlete ids, because of slightly different duplicate name
      athletes %>%
        pivot_longer(
          c('name', 'name_alt'),
          names_to = 'type',
          values_to = 'name'
        ) %>%
        filter(!is.na(name)) %>%
        select(
          name, birthday, athlete_id, gender
        ),
      by = c('name', 'birthday')
      ) %>%
    select(-name) %>%
    left_join( # replace name with 'selected' name if they have multiple
      athletes %>%
        select(name, athlete_id),
      by = 'athlete_id'
    ) %>%
    rename(
      snatch_best = total_lift1,
      cleanjerk_best = total_lift2,
      total = total_lift3
    ) %>%
    select( # set final order
      total_rank, snatch_rank, cleanjerk_rank,
      name, athlete_id, birthday, gender, nation, group, bw, category, dq, old_classes, event_id,
      snatch_lift1, snatch_lift2, snatch_lift3,
      snatch_best,
      cleanjerk_lift1, cleanjerk_lift2, cleanjerk_lift3,
      cleanjerk_best,
      total
    ) %>%
    arrange(category, group, total_rank) %>%
    return()
}

#clean_results(results_list[[378]]) # for testing

results_list_clean <- lapply(results_list, clean_results) # clean all

############# cleaning events #########################

events <- events_dirty %>%
  distinct() %>%
  mutate(
    date = as_date(date, format = '%b %d, %Y', tz = "GMT"),
    id = as.integer(id),
    location = str_remove_all(location, '\\t')
  ) %>%
  rename(
    event_id = id
  ) %>%
  arrange(event_id)

############### saving data ############

results_files_clean <- str_replace(results_files, 'raw_data', 'clean_data') # make new file paths
mapply(write_csv, x = results_list_clean, file = results_files_clean, num_threads = 36)

results = bind_rows(results_list_clean) %>% arrange(event_id, category, group, total_rank)

write_csv(results, './clean_data/all_results.csv')
write_csv(athletes, './clean_data/athletes.csv')
write_csv(events, './clean_data/events.csv')

########### all data as .Rdata ###########

save(results, events, athletes, file = './all_data.Rdata')

