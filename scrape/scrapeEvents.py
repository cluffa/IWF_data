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
    """Code chunk from OWL / Sport80 API"""
    with open(join(base_dir, f"{filepath_name}.csv"), 'w', encoding='utf-8') as file_boi:
        csv_writer = writer(file_boi)
        csv_writer.writerows(data)


def updateEvents():
    data_dir = dirname(__file__)


    urls = ["https://iwf.sport/results/results-by-events/?event_type=all&event_age=all&event_nation=all",
        "https://iwf.sport/results/results-by-events/results-by-events-old-bw/?event_type=all&event_age=all&event_nation=all"]


    all_bw_data = []
    for url in urls:
        req = requests.get(url)
        content = req.text

        soup = BeautifulSoup(content, 'html.parser').find('div', 'cards')
        event_ids = []
        for event_id in soup.find_all('a', 'card', href=True):
            event_ids.append(int(event_id['href'].replace('?event_id=', '')))

        event_name = []
        for event in soup.find_all('span', 'text'):
            event_name.append(event.get_text())

        event_dates = []
        for date in soup.find_all('div', 'col-md-2 col-4 not__cell__767'):
            event_dates.append(date.get_text().strip())

        event_locations = []
        for country in soup.find_all('div', 'col-md-3 col-4 not__cell__767'):
            event_locations.append(country.get_text().strip())

        zip_it = list(zip(event_ids, event_name, event_dates, event_locations))
        # The below line could stay in, rest of the code doesn't really care that it's a list of tuples vs a list
        # zip_it = [list(x) for x in zip_it]
        all_bw_data.extend(zip_it)

    all_bw_data = sorted(all_bw_data, key=lambda x: x[0], reverse=False)
    all_bw_data.insert(0, [x for x in EventHeaders.__annotations__])

    dir_path = f"{data_dir}/../raw_data/"
    write_to_csv(dir_path, "events", all_bw_data)

if __name__ == "__main__":
    updateEvents()
