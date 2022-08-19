# https://iwf.sport/results/results-by-events/?event_type=all&event_age=all&event_nation=all
# https://iwf.sport/results/results-by-events/results-by-events-old-bw/?event_type=all&event_age=all&event_nation=all

from bs4 import BeautifulSoup
import bs4
import requests
import pandas as pd
import numpy as np
import os

def updateEvents():
    combined = pd.DataFrame()

    dir = os.path.dirname(__file__)

    urls = ["https://iwf.sport/results/results-by-events/?event_type=all&event_age=all&event_nation=all",
        "https://iwf.sport/results/results-by-events/results-by-events-old-bw/?event_type=all&event_age=all&event_nation=all"]

    for url in urls:
        df = pd.DataFrame()
        req = requests.get(url)
        content = req.text
        soup = BeautifulSoup(content, "html.parser").find("div", "cards")

        ids = []
        for id in soup.find_all("a", "card", href=True):
            ids.append(int(id["href"].replace("?event_id=", "")))

        df["id"] = ids

        events = []
        for event in soup.find_all("span", "text"):
            events.append(event.get_text())

        df["event"] = events

        dates = []
        for date in soup.find_all("div", "col-md-2 col-4 not__cell__767"):
            dates.append(date.get_text().strip())

        df["date"] = dates

        locations = []
        for country in soup.find_all("div", "col-md-3 col-4 not__cell__767"):
            locations.append(country.get_text().strip().replace("  ", " "))

        df["location"] = locations

        combined = pd.concat([combined, df])

    file = f"{dir}/../raw_data/events.csv"
    combined.sort_values("id").to_csv(file, index=False)

if __name__ == "__main__":
    updateEvents()
