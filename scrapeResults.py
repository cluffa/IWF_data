# This script will scrape https://iwf.sport/results
# for iwf sanctioned event results

from bs4 import BeautifulSoup
import bs4
import requests
import pandas as pd
import numpy as np

def scrape_url(id: int = 522):
    """scrapes results page

    Args:
        id (int, optional): id of event. Defaults to 522.

    Returns:
        pd.DataFrame: an uncleaned dataframe
            also outputs to csv ./raw_data

    """

    if id < 441:
        old_classes = True
    else:
        old_classes = False

    if old_classes:
        url = 'https://iwf.sport/results/results-by-events/results-by-events-old-bw/?event_id=' + str(id)
    else:
        url = 'https://iwf.sport/results/results-by-events/?event_id=' + str(id)

    req = requests.get(url)
    content = req.text.replace('<strike>', '-').replace('</strike>', '')
    soup = BeautifulSoup(content, 'html.parser')

    event = soup.find('h2').text

    def get_text(soup):

        text = soup.get_text()
        
        lines = (line.strip() for line in text.splitlines())

        chunks = (phrase.strip() for line in lines for phrase in line.split("  "))

        text = '\n'.join(chunk for chunk in chunks if chunk)
        return text


    men = get_text(soup.find("div", {"id": "men_snatchjerk"})).splitlines()
    women = get_text(soup.find("div", {"id": "women_snatchjerk"})).splitlines()

    all = men + women

    def is_cat(line):
        return (('Men' in line) | ('Women' in line)) & ('kg' in line)

    def is_sec(line):
        return line in ['Snatch', 'Clean&Jerk', 'Total']

    heads = ['Rank:', 'Name:', 'Nation:', 'Born:', 'B.weight:', 'Group:', '1:', '2:', '3:', 'Total:', 'Snatch:', 'CI&Jerk:']
    def is_head(line):
        return line in heads

    def rep_list(list: str, matches = heads):
        x = list
        for match in matches:
            x = x.replace(match, '')
        return x.strip()

    def containsNumber(value):
        for character in value:
            if character.isdigit():
                return True
        return False

    df = pd.DataFrame({'rank':[], 'name':[], 'nation':[], 'born':[], 'bw':[], 'group':[], 'lift1':[], 'lift2':[], 'lift3':[], 'lift4':[], 'cat':[], 'sec':[]})
    row = []
    place = 0

    for line in all:

        if is_cat(line):
            cat = line.replace(' ', '')
        elif is_sec(line):
            sec = line.replace('&', '')
        elif is_head(line):
            col = 1
        else:
            row.append(line)
            if 'Total:' in line:
                
                while len(row) < 10: #a
                    row.append(np.nan)


                row.append(cat)
                row.append(sec)
                #print(row)
                

                df.loc[len(df)] = row
                row = []

    df['event'] = event
    file = './raw_data/results/' + str(id) + ' ' + event + '.csv'
    file = file.replace(' ', '_').replace('-', '_')
    df.to_csv(file, index=False)

    print('Event ID: ' + str(id))
    print('Event: ' + event)
    print('Saved To: ' + file)
    print('\n')

    #return df


def scrape_pass_errors(id):
    try:
        scrape_url(id)
    except:
        print('Failed ID: ' + str(id))
        print('\n')
        pass

import multiprocessing as mp

ids = pd.read_csv('./raw_data/events.csv')['id']

if __name__ == "__main__":
    pool = mp.Pool(mp.cpu_count())
    pool.map(scrape_pass_errors, ids)
    pool.close()

unlisted = [1, 87, 101, 136, 169, 316, 377, 505]

if __name__ == "__main__":
    pool = mp.Pool(mp.cpu_count())
    pool.map(scrape_pass_errors, unlisted)
    pool.close()