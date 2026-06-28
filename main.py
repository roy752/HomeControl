# %%
from fastapi import FastAPI
import requests, json

# %%
app = FastAPI()


@app.get('/health')
def health():
    return {'status': 'ok'}


# %%
def get_url(uri= ""):
    return "http://192.168.0.7" + "/" + uri.lstrip("/")

# %%
@app.get("/dht/hat")
def get_hat():
    url = get_url("hat")
    response = requests.get(url=url)
    response.raise_for_status()
    return json.loads(response.text)

# %%
@app.post(path="/ir/decode")
def request_ir_decode(timeout=5000):
    url = get_url("ir/decode")
    response = requests.post(url, {"timeout": timeout})
    response.raise_for_status()
    return json.loads(response.text)


# %%
@app.get("/ir/result_decode")
def get_ir_decode():
    url = get_url(uri="ir/result_decode")
    response = requests.get(url)
    response.raise_for_status()
    return json.loads(response.text)

# %%
@app.post(path="/ir/poweroff")
def ir_power_off():
    url = get_url(uri="ir/poweroff")
    response = requests.post(url=url)
    response.raise_for_status()
    return json.loads(response.text)

# %%
@app.post(path="/ir/poweron")
def ir_power_on():
    url = get_url(uri="ir/poweron")
    response = requests.post(url)
    response.raise_for_status()
    return json.loads(response.text)

# %%
@app.post("/ir/temperature")
def ir_adjust_temperature(temp: int = 25):
    url = get_url(uri="ir/temperature")
    response = requests.post(url=url, data={"value": temp})
    response.raise_for_status()
    return json.loads(response.text)

# %%
@app.post(path="/ir/wind")
def ir_adjust_wind(wind: int = 4):
    url = get_url(uri="ir/wind")
    response = requests.post(url=url, data={"value": wind})
    response.raise_for_status()
    return json.loads(response.text)

# %%
@app.get(path="/ir/status")
def ir_status():
    url = get_url(uri="ir/status")
    response = requests.get(url=url)
    response.raise_for_status()
    return json.loads(response.text)


# %%
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=11010)