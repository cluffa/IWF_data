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
going up in weight allows for more time between a missed lift and the
next. I will make a group for each of the two strategies. Each
observation is two subsequent lifts. The first lift is failed and the
second lift is either made or missed.

``` r
olympics <- events %>%  # only olympic results
  filter(is_olympics == 1) %>%
  select(event_id) %>%
  left_join(results, by = "event_id") %>%
  arrange(desc(date), total_rank)

pairs <- bind_rows(
    olympics %>% select(snatch_lift1, snatch_lift2) %>%
      rename(lift1 = snatch_lift1, lift2 = snatch_lift2) %>% 
      mutate(type = "snatch", pos = "12"),
    olympics %>% select(snatch_lift2, snatch_lift3) %>%
      rename(lift1 = snatch_lift2, lift2 = snatch_lift3) %>% 
      mutate(type = "snatch", pos = "23"),
    olympics %>% select(cleanjerk_lift1, cleanjerk_lift2) %>%
      rename(lift1 = cleanjerk_lift1, lift2 = cleanjerk_lift2) %>% 
      mutate(type = "cleanjerk", pos = "12"),
    olympics %>% select(cleanjerk_lift2, cleanjerk_lift3) %>%
      rename(lift1 = cleanjerk_lift2, lift2 = cleanjerk_lift3) %>% 
      mutate(type = "cleanjerk", pos = "23")
  ) %>% 
  filter(lift1 < 0, abs(lift2) > 0) %>% 
  mutate(
    jump = abs(lift2) - abs(lift1),
    made_lift2 = lift2 > 0) %>% 
  rowid_to_column()

pairs
```

    ## # A tibble: 1,491 × 7
    ##    rowid lift1 lift2 type   pos    jump made_lift2
    ##    <int> <dbl> <dbl> <chr>  <chr> <dbl> <lgl>     
    ##  1     1  -189   189 snatch 12        0 TRUE      
    ##  2     2  -137   137 snatch 12        0 TRUE      
    ##  3     3  -165   165 snatch 12        0 TRUE      
    ##  4     4  -115   115 snatch 12        0 TRUE      
    ##  5     5   -84    84 snatch 12        0 TRUE      
    ##  6     6  -165   165 snatch 12        0 TRUE      
    ##  7     7  -130   130 snatch 12        0 TRUE      
    ##  8     8  -101   101 snatch 12        0 TRUE      
    ##  9     9  -151   151 snatch 12        0 TRUE      
    ## 10    10  -102  -102 snatch 12        0 FALSE     
    ## # … with 1,481 more rows

Note that a negative weight means it is a failed attempt.

``` r
mean(pairs$made_lift2)
```

    ## [1] 0.4466801

Only 45% of lifts after a miss are made.

Splitting into groups. No jump and a jump \> 0.

``` r
big_jump <- pairs %>% filter(jump > 0)
no_jump <- pairs %>% filter(jump == 0)

made <- c(sum(big_jump$made_lift2), sum(no_jump$made_lift2))
total <- c(nrow(big_jump), nrow(no_jump))
tibble(jump = c("big", "none"), made, total, prop = made/total)
```

    ## # A tibble: 2 × 4
    ##   jump   made total  prop
    ##   <chr> <int> <int> <dbl>
    ## 1 big      72   232 0.310
    ## 2 none    594  1259 0.472

Proportion test with the hypotheses:
*H*<sub>0</sub> : *p*<sub>sucess after jump</sub> − *p*<sub>sucess after no jump</sub> = 0
*H*<sub>*A*</sub> : *p*<sub>sucess after jump</sub> − *p*<sub>sucess after no jump</sub> ≠ 0

``` r
prop.test(made, total)
```

    ## 
    ##  2-sample test for equality of proportions with continuity correction
    ## 
    ## data:  made out of total
    ## X-squared = 20.014, df = 1, p-value = 7.686e-06
    ## alternative hypothesis: two.sided
    ## 95 percent confidence interval:
    ##  -0.22961767 -0.09329871
    ## sample estimates:
    ##    prop 1    prop 2 
    ## 0.3103448 0.4718030

The results are significant. So it is safe to say that the benefits of
making a larger jump are not worth the increase risk of failing an
attempt.

I also want to test the difference when the two subsequent lifts are
first and second or second and third.

``` r
big_jump_23 <- pairs %>% filter(jump > 0, pos == "23")
no_jump_23 <- pairs %>% filter(jump == 0, pos == "23")
big_jump_12 <- pairs %>% filter(jump > 0, pos == "12")
no_jump_12 <- pairs %>% filter(jump == 0, pos == "12")

made_23 <- c(sum(big_jump_23$made_lift2), sum(no_jump_23$made_lift2))
total_23 <- c(nrow(big_jump_23), nrow(no_jump_23))
made_12 <- c(sum(big_jump_12$made_lift2), sum(no_jump_12$made_lift2))
total_12 <- c(nrow(big_jump_12), nrow(no_jump_12))

tibble(jump = c("big 23", "none 23", "big 12", "none 12"), made = c(made_23, made_12), total = c(total_23, total_12), prop = c(made_23/total_23, made_12/total_12))
```

    ## # A tibble: 4 × 4
    ##   jump     made total  prop
    ##   <chr>   <int> <int> <dbl>
    ## 1 big 23     58   191 0.304
    ## 2 none 23   296   775 0.382
    ## 3 big 12     14    41 0.341
    ## 4 none 12   298   484 0.616

``` r
prop.test(made_23, total_23)
```

    ## 
    ##  2-sample test for equality of proportions with continuity correction
    ## 
    ## data:  made_23 out of total_23
    ## X-squared = 3.7134, df = 1, p-value = 0.05398
    ## alternative hypothesis: two.sided
    ## 95 percent confidence interval:
    ##  -0.155173832 -0.001367293
    ## sample estimates:
    ##    prop 1    prop 2 
    ## 0.3036649 0.3819355

``` r
prop.test(made_12, total_12)
```

    ## 
    ##  2-sample test for equality of proportions with continuity correction
    ## 
    ## data:  made_12 out of total_12
    ## X-squared = 10.68, df = 1, p-value = 0.001083
    ## alternative hypothesis: two.sided
    ## 95 percent confidence interval:
    ##  -0.4389486 -0.1095295
    ## sample estimates:
    ##    prop 1    prop 2 
    ## 0.3414634 0.6157025

The probabilities for 2 & 3 are much closer than 1 & 2.

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
    ## 1      11627 ROGERS Martha   ROGERS Martha Ann      1995-08-23    W      USA    
    ## 2        820 ALWINE Meredith ALWINE Meredith Leigh  1998-06-08    W      USA    
    ## 3       9952 NYE Katherine   NYE Katherine Elizabe… 1999-01-05    W      USA
