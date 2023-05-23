import std;
import std.net.curl: get;
import std.json;
import std.container : DList;
import std.conv: to;
import std.format: format;
import std.file: readText, write;
import std.string: strip;
import std.array: empty;
import vibe.vibe;

string getRequest(string id, string range, string api_key) {
  char[] response = get(format("https://sheets.googleapis.com/v4/spreadsheets/%s/values/%s/?key=%s", id, range, api_key));
  string content = "";
  foreach (ch; response)
    content ~= ch;
  return content;
}

string[string] parseConfig()
{
  string[string] map;
  auto content = readText("./config.json");
  JSONValue json = parseJSON(content);
  map["id"] = json["id"].str;
  map["range"] = json["range"].str;
  map["api_key"] = json["api_key"].str;
  return map;
}

JSONValue[] parseResponse(string id, string range, string api_key) {
    
  auto response = getRequest(id, range, api_key);
  JSONValue json = parseJSON(response);
  string[] keys = [];
  bool isKeys = true;
  JSONValue[] obj = [];
  foreach(index, value; json["values"].array) {
    if (value.array.length == 0)
      {
	continue;
      }

    if (isKeys)
      {
	foreach(key; value.array) {
	  if (key.str.strip.length == 0) continue;
	  keys ~= key.str;
	}
	if (keys.length == 0) continue;
	isKeys = false;
	continue;
      }

    JSONValue values;

    if (value.array.length >= keys.length) {
      for (ulong i = 0; i < keys.length; i++)
	{
	  if (value.array[i].str.strip.length == 0)
	    {
	      values[keys[i]] = null;
	      continue;
	    }
	  values[keys[i]] = value.array[i].str;
	}
      obj ~= JSONValue(values);
      continue;
    }

    foreach (i, val; value.array)
      {
	if (val.str.strip.length == 0)
	  {
	    values[keys[i]] = null;
	    continue;
	  }
	values[keys[i]] = val.str;
      }

    for(ulong i = value.array.length; i < keys.length; i++) {
      values[keys[i]] = null;
    }
    obj ~= JSONValue(values);
  }

  return obj;
}

void main()
{
  try
    {
      auto config = parseConfig();
      listenHTTP("127.0.0.1:8080", (req, res) {
	  auto sheet = parseResponse(config["id"], config["range"], config["api_key"]);
	  res.contentType("application/json");
	  res.writeJsonBody(sheet, 200);
	});
      runApplication();
    } catch (Exception ex) {
    std.stdio.writeln(ex.msg);
  }
}
