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

results_names_dirty <- results_list %>%
  lapply(function(df) df[c('name', 'nation', 'born', 'cat')]) %>%
  bind_rows() %>%
  filter(
    str_length(nation) == 3
  ) %>% 
  mutate(
    gender = if_else(str_detect(cat, 'Women'), 'W', 'M')
  ) %>%
  rename(
    country = nation # final is nation, but set to country to match
  ) %>%
  select(
    -cat
  ) %>%
  unique()

athletes <- athletes_dirty %>% 
  bind_rows(results_names_dirty) %>% 
  distinct() %>%
  mutate(
    birthday = as.Date(born, '%b %d, %Y'),
    nation = country
  ) %>% 
  mutate(names_split = name) %>% 
  separate(col = names_split, into = c('last', 'first'), sep = ' ') %>% # separate names
  group_by(birthday, gender, last, first) %>% # group
  summarize(matches = length(name), name = toString(name), nation = toString(nation)) %>% # matching names sep by comma
  ungroup() %>% 
  separate(col = name, into = c('name', 'name_alt'), sep = ', ') %>% # split alt names by comma
  mutate(name_alt = ifelse(name == name_alt, NA, name_alt)) %>% 
  separate(col = nation, into = c('nation_current', 'nation_all', 'nation_all2', 'nation_all3'), sep = ', ') %>% # split alt names by comma
  mutate( # fix duplicate nation in nation all
    nation_all3 = ifelse(nation_all3 == nation_all2, NA, nation_all3),
    nation_all3 = ifelse(nation_all3 == nation_all, NA, nation_all3),
    nation_all3 = ifelse(nation_all3 == nation_current, NA, nation_all3),
    nation_all2 = ifelse(nation_all2 == nation_all, NA, nation_all2),
    nation_all2 = ifelse(nation_all2 == nation_current, NA, nation_all2),
    nation_all = ifelse(nation_all == nation_current, NA, nation_all)
    ) %>% 
  unite(
    nation_all,
    c('nation_current', 'nation_all', 'nation_all2', 'nation_all3'),
    sep = ', ',
    na.rm = TRUE,
    remove = FALSE
  ) %>% 
  rowid_to_column('athlete_id') %>% 
  select( # final order
    athlete_id, name, name_alt, birthday, gender, nation_current, nation_all
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
    left_join(
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
    date = as.Date(date, '%b %d, %Y'),
    id = as.numeric(id),
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
