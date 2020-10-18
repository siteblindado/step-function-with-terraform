import logging, json, urllib3

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

HTTP = urllib3.PoolManager()
ENDPOINT = 'https://urlscan.io/api/v1/'


def handler(event, context):
    event['sleep_seconds'] = 2  # Tempo default para sleep em segundos
    api_key = event['api_key'] 
    scan_url = event['scan_url']

    scan_status = event.get('scan_status')
    scan_uuid = event.get('scan_uuid')
    scan_result =  event.get('result')

    if scan_status in ['new', None]:
        event['scan_uuid'] = submission_scan(api_key, scan_url)
        event['scan_status'] = 'running'
    elif scan_status == 'running':
        response = check_scan(scan_uuid)
        if response.status == 200:
            event['scan_status'] = 'done'
            event['result'] = json.loads(response.data.decode()).get('verdicts')
        elif response.status == 404:  # resposta padrão da API enquanto está processando o scan
            event['sleep_seconds'] = 10
    elif scan_status == 'done':
        done(scan_result)

    return event


def submission_scan(api_key, scan_url):
    headers = {'API-Key': api_key, 'Content-Type': 'application/json'}
    data = {"url": scan_url, "visibility": "public"}
    encoded_data = json.dumps(data).encode('utf-8')

    response = HTTP.request('POST', f'{ENDPOINT}scan/', headers=headers, body=encoded_data)
    return json.loads(response.data.decode())['uuid']


def check_scan(scan_uuid):
    response = HTTP.urlopen('GET', f'{ENDPOINT}result/{scan_uuid}')
    return response


def done(scan_result):
    LOGGER.info(f'Scan Result: {scan_result}')
