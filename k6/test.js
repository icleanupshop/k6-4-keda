import http from 'k6/http';

import { sleep } from 'k6';


export default function () {

  http.get('http://172.18.0.2');

  sleep(1);

}
