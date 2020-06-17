class CORSHandler
  include HTTP::Handler

  # Origins that your API allows
  ALLOWED_ORIGINS = [
    # Allows for local development
    /\.lvh\.me/,
    /localhost/,
    /127\.0\.0\.1/,

    # Add your production domains here
    # /production\.com/
  ]

  def call(context)
    request_origin = context.request.headers["Origin"]? || "localhost"

    # Setting the CORS specific headers.
    # Modify according to your apps needs.
    context.response.headers["Access-Control-Allow-Origin"] = allowed_origin?(request_origin) ? request_origin : ""
    context.response.headers["Access-Control-Allow-Credentials"] = "true"
    context.response.headers["Access-Control-Allow-Methods"] = "POST,GET,OPTIONS"
    context.response.headers["Access-Control-Allow-Headers"] = "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization"

    # If this is an OPTIONS call, respond with just the needed headers.
    if context.request.method == "OPTIONS"
      context.response.status = HTTP::Status::NO_CONTENT
      context.response.headers["Access-Control-Max-Age"] = "#{20.days.total_seconds.to_i}"
      context.response.headers["Content-Type"] = "text/plain"
      context.response.headers["Content-Length"] = "0"
      context
    else
      call_next(context)
    end
  end

  private def allowed_origin?(request_origin)
    ALLOWED_ORIGINS.find(false) do |pattern|
      pattern === request_origin
    end
  end
end
