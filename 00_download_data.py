"""Step 0: download the public UCI "Online Retail" dataset and save it as data/online_retail.csv.

Source: https://archive.ics.uci.edu/dataset/352/online-retail  (CC BY 4.0)
541,909 line items from a UK online gift retailer, 01 Dec 2010 - 09 Dec 2011.
"""
import io
import urllib.request
import zipfile
from pathlib import Path

import pandas as pd

URL = "https://archive.ics.uci.edu/static/public/352/online%2Bretail.zip"
OUT = Path(__file__).parent / "data" / "online_retail.csv"


def main() -> None:
    OUT.parent.mkdir(exist_ok=True)
    print("Downloading ...")
    raw = urllib.request.urlopen(URL, timeout=120).read()
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        with z.open("Online Retail.xlsx") as f:
            df = pd.read_excel(f)
    df.to_csv(OUT, index=False)
    print(f"Saved {len(df):,} rows -> {OUT}")


if __name__ == "__main__":
    main()
