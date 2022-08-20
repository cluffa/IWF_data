# https://iwf.sport/results/results-by-events/?event_type=all&event_age=all&event_nation=all
# https://iwf.sport/results/results-by-events/results-by-events-old-bw/?event_type=all&event_age=all&event_nation=all

from bs4 import BeautifulSoup
import requests
from dataclasses import dataclass
from os.path import join, dirname
from csv import writer


@dataclass
class EventHeaders:
    """Standard headers for the events index"""
    id: int
    name: str
    date: str
    location: str


def write_to_csv(base_dir, filepath_name, data):
    """yes"""
    print(f"creating {filepath_name}.csv...")
    with open(join(base_dir, f"{filepath_name}.csv"), 'w', encoding='utf-8') as file_boi:
        csv_writer = writer(file_boi)
        csv_writer.writerows(data)


def updateEvents():
    data_dir = dirname(__file__)

    urls = ['https://iwf.sport/results/results-by-events/?event_type=all&event_age=all&event_nation=all',
            'https://iwf.sport/results/results-by-events/results-by-events-old-bw/?event_type=all&event_age=all&event_nation=all']

    all_bw_data = []
    for url in urls:
        df = {}
        req = requests.get(url)
        content = req.text
        soup = BeautifulSoup(content, 'html.parser').find('div', 'cards')
        ids = []
        for id in soup.find_all('a', 'card', href=True):
            ids.append(int(id['href'].replace('?event_id=', '')))

        df['id'] = ids

        events = []
        for event in soup.find_all('span', 'text'):
            events.append(event.get_text())

        df['event'] = events

        dates = []
        for date in soup.find_all('div', 'col-md-2 col-4 not__cell__767'):
            dates.append(date.get_text().strip())

        df['date'] = dates

        locations = []
        for country in soup.find_all('div', 'col-md-3 col-4 not__cell__767'):
            locations.append(country.get_text().strip())

        df['location'] = locations

        # combined = combined.append(df)

        zip_it = list(zip(df['id'], df['event'], df['date'], df['location']))
        zip_it = [list(x) for x in zip_it]
        all_bw_data.extend(zip_it)

    filename = 'events_new'
    dir_path = f"{data_dir}/../raw_data/"
    all_bw_data.insert(0, [x for x in EventHeaders.__annotations__])
    write_to_csv(dir_path, filename, all_bw_data)


if __name__ == '__main__':
    updateEvents()