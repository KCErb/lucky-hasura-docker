# Find the timestamp of the most recent migration in the migrations dir.
# Should be equivalent to ls -v db/migrations | sed 's/\([0-9]*\).*/\1/' | tail -1
# But I hope this is more readable.
d = Dir.new("db/migrations")
puts d.children            # ["20200429175311_create_versions.cr", ".keep", ...]
	.map(&.split("_").first) # ["20200429175311", ".keep", "0000000001"]
	.select(/^\d*$/)         # ["20200429175311", "0000000001"]
	.map(&.to_i64)           # [20200429175311, 1]
  .sort                    # [1, 20200429175311]
  .pop                     # 20200429175311
  