# IWF Event Results, Athletes, anaylsis

## Overview

The data was scraped from the IWF website. The results are most, if not all, results from IWF sanction events back to the 2004 Olympic Games in Athens. This can be found in `clean_data/all_results.csv` or separated by event in the `clean_data/results` folder. Athlete data can be found in `clean_data/athletes.csv`. Event data can be found in `clean_data/events.csv`. Athlete data and event data both have ids that match to the results. All the data as R data.frames with correct data types can be found in the `all_data.Rdata` file.

## Data Sources

athletes:  
<https://iwf.sport/results/results-by-events/?athlete_name=&athlete_gender=all&athlete_nation=all>

events:  
Weight classes changed recently, so there are two different pages  
<https://iwf.sport/results/results-by-events/?event_type=all&event_age=all&event_nation=all>  
<https://iwf.sport/results/results-by-events/results-by-events-old-bw/?event_type=all&event_age=all&event_nation=all>

results:  
where "?event_id=" comes from events, old classes page is id < 441  
<https://iwf.sport/results/results-by-events/results-by-events-old-bw/?event_id=300>  
<https://iwf.sport/results/results-by-events/?event_id=522>

There are also a few unlisted results pages. They are ids = [1, 87, 101, 136, 169, 316, 377, 505]

## Data Info

### Athletes

**variable**|**description**|**key**
:-----:|:-----:|:-----:
athlete_id | id |
name| name |
name_alt| alternate name if more than one were used|
birthday| date of birth | YYYY-MM-DD
gender | gender | M = man, W = woman
nations | all nations athlete has compteted under | SO 3166 country code

### Results

**variable**|**description**|**key**
:-----:|:-----:|:-----:
total\_rank|rank in the total|
snatch\_rank|rank in the snatch|all NA if no medal given at event (ex: Olympics)
cleanjerk\_rank|rank in the clean and jerk|all NA if no medal given at event
name|athlete name|
athlete\_id|athlete id|key to athletes data
date\_of\_birth|date of birth| YYYY-MM-DD
age|age day of event| years
gender|gender|M = Man, W = Woman
nation|country they are competing for|ISO 3166 country code
group|group session|A=final=best
bw|body weight|in KG
category|weight class/category| + = lower limit
dq|was disqualified|0 = no, 1 = yes
old\_classes|is category from the old weight classes|0 = no, 1 = yes
event\_id|event id|key to events data
event|event name|  
date|date of event start|  
snatch\_lift1|absolute value is 1st snatch attempt|negative = miss
snatch\_lift2|2nd snatch attempt|negative = miss
snatch\_lift3|3rd snatch attempt|negative = miss
snatch\_best|best snatch out of three attempts|
cleanjerk\_lift1|1st clean and jerk attempt|negative = miss
cleanjerk\_lift2|2nd clean and jerk attempt|negative = miss
cleanjerk\_lift3|3rd clean and jerk attempt|negative = miss
cleanjerk\_best|best clean and jerk out of three attempts|
total|sum of best snatch and best clean and jerk|

### Events

**variable**|**description**|**key**
:-----:|:-----:|:-----:
event_id | id |
event | event name |
date | date of event | YYYY-MM-DD
location | location of event | city, ISO 3166 country code
age\_group|youth, junior, or senior|
is\_olympics|is event olympic games, subset of senior|
is\_university|is event universities, subset of junior|
