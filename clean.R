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
iso_codes <- read_csv("./clean_data/iso_code.csv", show_col_types = FALSE)

############# manual fixes ##############

fix_dob <- function(data, athlete_name, real_dob) {
  if(length(athlete_name) > 1) { # apply for all names if more than 1
    for (i in 1:length(athlete_name)) {
      data = fix_dob(data, athlete_name[i], real_dob[i])
    }
    return(data)
  } else if('list' %in% class(data)) { # apply to all dfs if list of dfs
    return(lapply(data, fix_dob, athlete_name = athlete_name, real_dob = real_dob))

  } else if('data.frame' %in% class(data)) { # apply to single df, single name
    data$born = if_else(data$name == athlete_name, real_dob, data$born)
    return(data)

  } else {
    stop()
  }
}

overrides <- data.frame(
  names = c('ALWINE Meredith'),
  real_dob = c('Jun 08, 1998')
)

# function applied under after setting athlete id

################ cleaning athletes #####################

# there are many athletes that have the multiple rows
# with different or no middle name or extension.
# grouping by lastname, firstname, nation, date_of_birth
# gives 44 matches. I have reviewed all, and can say
# these are real matches.
#

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

# making id before filter that won't change
athlete_ids <- bind_rows(
  results_names_dirty,
  athletes_dirty %>%
    select(name, country, born, gender) %>%
    rename(nation = country)
  ) %>%
  unique() %>%
  rowid_to_column('athlete_id') %>%
  fix_dob(overrides$names, overrides$real_dob) %>%
  mutate(date_of_birth = as_date(born, format = '%b %d, %Y')) %>%
  select(athlete_id, name, gender, date_of_birth)

results_list <- fix_dob(results_list, overrides$names, overrides$real_dob)
results_names_dirty <- fix_dob(results_names_dirty, overrides$names, overrides$real_dob)
athletes_dirty <- fix_dob(athletes_dirty, overrides$names, overrides$real_dob)

athletes <- athletes_dirty %>%
  mutate(
    nation = country
  ) %>%
  bind_rows(results_names_dirty) %>%
  distinct() %>%
  mutate(
    date_of_birth = as_date(born, format = '%b %d, %Y')
  ) %>%
  mutate(names_split = name) %>%
  separate(col = names_split, into = c('last', 'first'), sep = ' ') %>% # separate names
  group_by(date_of_birth, gender, last, first) %>% # group
  summarize(matches = length(name), name = toString(name), nations = toString(nation)) %>% # matching names sep by comma
  ungroup() %>%
  separate(col = name, into = c('name', 'name_alt'), sep = ', ') %>% # split alt names by comma
  mutate( # remove name_alt if not different than name, remove duplicate nations
    name_alt = ifelse(name == name_alt, NA, name_alt),
    nations = sapply(str_split(nations, ', '), function(x) toString(unique(x)))
    ) %>%
  left_join(
    athlete_ids,
    by = c('name', 'date_of_birth', 'gender')
  ) %>%
  select( # final order
    athlete_id, name, name_alt, date_of_birth, gender, nations
  ) %>% suppressWarnings()

############# cleaning events #########################
get_age_group <- function(event_name) {
  if(length(event_name) > 1) {
    return(as.vector(sapply(event_name, get_age_group)))
  } else if(grepl('youth', event_name, ignore.case = TRUE)) {
    return('youth')
  } else if(grepl('junior|university', event_name, ignore.case = TRUE)) {
    return('junior')
  } else {
    return('senior')
  }
}

events <- events_dirty %>%
  distinct() %>%
  mutate(
    location = str_remove_all(location, '\\t')
  ) %>%
  separate(
    col = location,
    into = c("city", "iso_code", "other"),
    sep = ", "
  ) %>%
  mutate(
    city = if_else(!is.na(other), paste(city, iso_code), city),
    iso_code = if_else(!is.na(other), other, iso_code),
    other = NULL,
    date = as_date(date, format = '%b %d, %Y'),
    id = as.integer(id),
    age_group = get_age_group(event),
    is_olympics = as.integer(
      grepl('olympic games', event, ignore.case = TRUE) & !grepl('test|youth', event, ignore.case = TRUE)
      ),
    is_university = as.integer(grepl('university', event, ignore.case = TRUE))
  ) %>%
  rename(
    event_id = id
  ) %>%
  left_join(
    iso_codes %>%
      rename(iso_code = `Alpha-3 code`, country = `English short name lower case`) %>%
      select(iso_code, country),
    by = "iso_code"
  ) %>%
  arrange(event_id)

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
    left_join(events %>% select(event_id, date, event), by = 'event_id') %>%
    mutate(
      dq = (rank == 'DSQ'), # total rank is 'DSQ' if disqualified, usually due to testing positive for PEDs
      born = ifelse(name == 'ALWINE Meredith', 'Jun 08, 1998', born), # override errors
      date_of_birth = as_date(born, format = '%b %d, %Y'), # convert to date
      age = round(interval(date_of_birth, date) / years(1), 1),
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
      id_cols = c(name, dq, nation, date_of_birth, bw, group, category, event_id, old_classes, age, date, event),
      #id_cols = - c(sec, lift1, lift2, lift3, rank),
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
          name, date_of_birth, athlete_id, gender
        ),
      by = c('name', 'date_of_birth')
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
      name, athlete_id, date_of_birth, age, gender, nation, group, bw, category, dq, old_classes, event_id, event, date,
      snatch_lift1, snatch_lift2, snatch_lift3,
      snatch_best,
      cleanjerk_lift1, cleanjerk_lift2, cleanjerk_lift3,
      cleanjerk_best,
      total
    ) %>%
    arrange(category, group, total_rank) %>%
    suppressWarnings() %>%
    suppressMessages() %>%
    return()
}

#clean_results(results_list[[378]]) # for testing

results_list_clean <- lapply(results_list, clean_results) # clean all

############### saving data ############

results_files_clean <- str_replace(results_files, 'raw_data', 'clean_data') # make new file paths
mapply(write_csv, x = results_list_clean, file = results_files_clean, num_threads = 36)

results = bind_rows(results_list_clean) %>% arrange(event_id, category, group, total_rank)

write_csv(results, './clean_data/all_results.csv')
write_csv(athletes, './clean_data/athletes.csv')
write_csv(events, './clean_data/events.csv')

########### all data as .Rdata ###########

save(results, events, athletes, file = './all_data.Rdata')
#rm(list = ls(all.names = TRUE))
