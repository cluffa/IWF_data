# https://iwf.sport/results/results-by-events/?athlete_name=&athlete_gender=all&athlete_nation=all

from bs4 import BeautifulSoup
import bs4
import requests
import pandas as pd
import numpy as np
df = pd.DataFrame({'name':[], 'born':[], 'gender':[], 'country':[]})

url = 'https://iwf.sport/results/results-by-events/?athlete_name=&athlete_gender=all&athlete_nation=all'

req = requests.get(url)
content = req.text
soup = BeautifulSoup(content, 'html.parser').find('div', 'cards')

for line in soup.find_all('div', 'row'):
    row = []
    for item in line:
        row.append(item.get_text().strip().split(': ')[-1])

    temp = pd.DataFrame({'name':[row[1]], 'born':[row[3]], 'gender':[row[5]], 'country':[row[7]]})

    df = df.append(temp)

print(df.head(10))
df.to_csv('./raw_data/athletes.csv', index=False)
