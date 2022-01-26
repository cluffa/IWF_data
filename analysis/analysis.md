Analysis of International Weightlifting Competitions (in progress)
================

  The sport of weightlifting has a long history. It was first included
in the Olympics in the 1896. Today there are two lifts; the snatch and
the clean and jerk. There were originally many lifts, including one and
two hand versions. By 1928 there was the snatch, clean and jerk, and the
clean and press. In 1972 the press was removed and we’re left with the
two lifts we have today.  
  While it may seem like just a competition to see who can lift the
most, it is much more complicated than that. There are weight
categories. 10 per gender per age group. Each lift gets three attempts.
The competition starts off with with each athlete declaring an opening
snatch. The lowest weight is then put onto the bar. Each athlete then
goes out and attempts their declared weight. They have one minute to do
so after bar has been set. After each attempt, the athlete must declare
their next weight. The weight on the bar can never go down. In the case
of an athlete missing an attempt, they must try the same weight a second
time or go up in weight. When they increase the weight it puts a few
attempts from other athletes in front of them. This is a trade-off
between rest time and weight on the bar. This is one of the things I
will be looking at in my analysis. Athletes fall one by one as they each
take their third attempt. The last three athletes that successfully make
an attempt, and therefore lifted the most weight, are guaranteed a medal
for the snatch portion. There is a 15 minute break between sessions, and
then the same process is repeated for clean and jerk. At the end there
is also three medals given to the athletes who lift the most combined,
called the total. This medal holds much more weight than the other two.
The gold medal winner in the total is called the category champion.

|       Clean and Jerk       |          Snatch          |
|:--------------------------:|:------------------------:|
| ![ilya](./images/ilya.gif) | ![liu](./images/liu.gif) |

# Competition Strategy

One of the most important aspects of the competition is allocating
enough rest. As mentioned in the intro, it is a common strategy to go up
in weight even if an athlete has missed an attempt. This is because
going up in weight allows others to make their attempts before the need
to go back up to the platform. I will make a group for each of the two
strategies. Each observation is two subsequent lifts. The first lift is
failed and the second lift is either made or missed.

``` r
pairs <- bind_rows(
    results %>% select(snatch_lift1, snatch_lift2) %>%
      rename(lift1 = snatch_lift1, lift2 = snatch_lift2) %>% 
      mutate(type = "snatch", pos = "12"),
    results %>% select(snatch_lift2, snatch_lift3) %>%
      rename(lift1 = snatch_lift2, lift2 = snatch_lift3) %>% 
      mutate(type = "snatch", pos = "23"),
    results %>% select(cleanjerk_lift1, cleanjerk_lift2) %>%
      rename(lift1 = cleanjerk_lift1, lift2 = cleanjerk_lift2) %>% 
      mutate(type = "cleanjerk", pos = "12"),
    results %>% select(cleanjerk_lift2, cleanjerk_lift3) %>%
      rename(lift1 = cleanjerk_lift2, lift2 = cleanjerk_lift3) %>% 
      mutate(type = "cleanjerk", pos = "23")
  ) %>% 
  filter(lift1 < 0, abs(lift2) > 0) %>% 
  mutate(
    jump = abs(lift2) - abs(lift1),
    made_lift2 = lift2 > 0) %>% 
  rowid_to_column()

head(pairs)
```

    ## # A tibble: 6 × 7
    ##   rowid lift1 lift2 type   pos    jump made_lift2
    ##   <int> <dbl> <dbl> <chr>  <chr> <dbl> <lgl>     
    ## 1     1  -186  -190 snatch 12        4 FALSE     
    ## 2     2  -193   193 snatch 12        0 TRUE      
    ## 3     3  -187   187 snatch 12        0 TRUE      
    ## 4     4  -180  -180 snatch 12        0 FALSE     
    ## 5     5  -177   177 snatch 12        0 TRUE      
    ## 6     6  -125   125 snatch 12        0 TRUE

Negative weight means it is a miss. Right off the top we can see
examples of each strategy. The first observation missed 186 and went up
to 190 only to miss again. The rest stayed at the first weight and 4/5
made it.

``` r
mean(pairs$made_lift2)
```

    ## [1] 0.5093273

Only 51% of lifts after a miss are made.

I will make separate the two. No jump and a jump \> 0.

``` r
big_jump <- pairs %>% filter(jump > 0)
no_jump <- pairs %>% filter(jump == 0)
```

``` r
made <- c(sum(big_jump$made_lift2), sum(no_jump$made_lift2))
total <- c(nrow(big_jump), nrow(no_jump))
tibble(jump = c("big", "none"), made, total, prop = made/total)
```

    ## # A tibble: 2 × 4
    ##   jump   made total  prop
    ##   <chr> <int> <int> <dbl>
    ## 1 big    4042  9637 0.419
    ## 2 none  24241 45860 0.529

A quick proportion test.

``` r
prop.test(made, total)
```

    ## 
    ##  2-sample test for equality of proportions with continuity correction
    ## 
    ## data:  made out of total
    ## X-squared = 379.29, df = 1, p-value < 2.2e-16
    ## alternative hypothesis: two.sided
    ## 95 percent confidence interval:
    ##  -0.12008462 -0.09823912
    ## sample estimates:
    ##    prop 1    prop 2 
    ## 0.4194251 0.5285870

example athlete comparison

``` r
results_long <- results %>% # a dataset where each best lift/total is another line
  select(-contains('lift')) %>% 
  pivot_longer(c('snatch_best', 'cleanjerk_best', 'total'), names_to = 'lift', values_to = 'weight') %>% 
  mutate(lift = str_remove(lift, '_best'))
```

``` r
search <- athletes %>% filter(
  grepl('katherine|martha|alwine', name, ignore.case = TRUE),
  grepl('USA', nations)
  )
ids <- search$athlete_id

results_long %>%
  left_join(events %>% select(event_id, age_group), by = 'event_id') %>%
  filter(
    sapply(athlete_id, function(id) id %in% ids),
    !is.na(weight)) %>% 
  ggplot(aes(x = age, y = weight, color = name)) +
    geom_line() +
    geom_point() +
    facet_wrap(vars(lift), scales = 'free', ncol = 1) +
    labs(title = 'comparison')
```

![](analysis_files/figure-gfm/unnamed-chunk-7-1.png)<!-- -->

``` r
search
```

    ## # A tibble: 3 × 6
    ##   athlete_id name            name_alt               date_of_birth gender nations
    ##        <int> <chr>           <chr>                  <date>        <chr>  <chr>  
    ## 1      13402 ROGERS Martha   ROGERS Martha Ann      1995-08-23    W      USA    
    ## 2      13391 ALWINE Meredith ALWINE Meredith Leigh  1998-06-08    W      USA    
    ## 3      13399 NYE Katherine   NYE Katherine Elizabe… 1999-01-05    W      USA
