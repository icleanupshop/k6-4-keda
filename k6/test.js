import http from 'k6/http';

import { sleep } from 'k6';


export default function () {

  http.get('http://<<ECHO_SERVER_IP_ADDRESS>>');

  sleep(1);

}
