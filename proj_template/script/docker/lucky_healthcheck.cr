require "http/client"

response = HTTP::Client.get "http://localhost:5000/version"
exit response.status_code == 200 ? 0 : 1
