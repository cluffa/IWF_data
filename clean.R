library(tidyverse)
library(stringr)

update_data <- FALSE

if(update_data) {
  library(reticulate)
  use_condaenv('base')
  py_run_file('./scrapeEvents.py')
  py_run_file('./scrapeAthletes.py')
  py_run_file('./scrapeResults.py')
}

########## reading in files ###########

results_files <- list.files('./raw_data/results/', full.names = TRUE)
results_list <- lapply(results_files, read_csv, show_col_types = FALSE, num_threads = 36)
events_dirty <- read_csv("./raw_data/events.csv", show_col_types = FALSE)
athletes_dirty <- read_csv("./raw_data/athletes.csv", show_col_types = FALSE)

################ cleaning athletes #####################

# there are many athletes that have the multiple rows
# with different or no middle name or extension.
# grouping by lastname, firstname, nation, birthday
# gives 44 matches. I have reviewed all, and can say
# these are real matches.

# results_names <- results_list %>% 
#   lapply(function(df) df[c('name', 'nation', 'born', 'cat')]) %>% 
#   bind_rows() %>% 
#   mutate(
#     gender = if_else(str_detect(cat, 'Women'), 'W', 'M')
#   ) %>% 
#   rename(
#     birthday = born
#   ) %>% 
#   select(
#     -cat
#   ) %>% 
#   unique()


athletes <- athletes_dirty %>% 
  distinct() %>%
  mutate(
    birthday = as.Date(birthday, '%b %d, %Y'),
    nation = country
  ) %>% 
  mutate(names_split = name) %>% 
  separate(col = names_split, into = c('last', 'first'), sep = ' ') %>% # separate names
  group_by(birthday, gender, nation, last, first) %>% # group
  summarize(matches = length(name), name = toString(name)) %>% # matching names sep by comma
  ungroup() %>% 
  separate(col = name, into = c('name', 'name_alt'), sep = ', ') %>% # split alt names by comma
  rowid_to_column('id') %>% 
  select( # final order
    id, name, name_alt, birthday, gender, nation
  ) %>% suppressWarnings()

#################### the cleaning function for results ########################

clean_results <- function(df) {
  df %>%
    arrange(desc(event_id)) %>% 
    distinct() %>% 
    replace_na(
      list('---', '')
    ) %>% 
    mutate(
      dq = (rank == 'DSQ'),
      birthday = as.Date(born, '%b %d, %Y'), # convert to date
      across( # fix spaces between '-' and number
        c(rank, bw, lift1, lift2, lift3),
        str_remove_all,
        pattern = ' '
      ),
      across( # convert to numeric
        c(rank, bw, lift1, lift2, lift3, event_id, old_classes, dq),
        as.numeric
      ) %>% suppressWarnings(),
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
    # join athlete ids, because of slightly different duplicate names
    # left_join(athletes, by = c('name', 'birthday'), suffix = rep('_join1',2)) %>% 
    # left_join(athletes,by = c('name' = 'name_alt', 'birthday'), suffix = rep('join_2',2)) %>% 
    rename(
      athlete_id = idathlete,
      gender = genderathlete,
      snatch_best = total_lift1,
      cleanjerk_best = total_lift2,
      total = total_lift3
    ) %>%
    # select( # set final order
    #   total_rank, snatch_rank, cleanjerk_rank,
    #   name, athlete_id, birthday, gender, nation, group, category, dq, old_classes, event_id,
    #   snatch_lift1, snatch_lift2, snatch_lift3,
    #   snatch_best,
    #   cleanjerk_lift1, cleanjerk_lift2, cleanjerk_lift3,
    #   cleanjerk_best,
    #   total
    # ) %>%
    arrange(category, total_rank) %>%
    return()
}

clean_results(results_list[[385]])

results_list_clean <- lapply(results_list, clean_results) # clean all

############# cleaning events #########################

events <- events_dirty %>% 
  distinct() %>% 
  mutate(
    date = as.Date(date, '%b %d, %Y'),
    id = as.numeric(id)
  ) %>% 
  arrange(id)

############### saving data ############

results_files_clean <- str_replace(results_files, 'raw_data', 'clean_data') # make new file paths
mapply(write_csv, x = results_list_clean, file = results_files_clean, num_threads = 36)

results = bind_rows(results_list_clean) %>% arrange(event_id, category, total_rank)

write_csv(results, './clean_data/all_results.csv')
write_csv(athletes, './clean_data/athletes.csv')
write_csv(events, './clean_data/events.csv')

########### all data as .Rdata ###########

save(results, events, athletes, file = './all_data.Rdata')
