#!/usr/bin/env python3

import sys
import yaml
import json
from datetime import datetime


class DateTimeEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, datetime):
            return obj.isoformat()
        return super(DateTimeEncoder, self).default(obj)


input_data = sys.stdin.read()
yaml_data = yaml.safe_load(input_data)
json_data = json.dumps(yaml_data, indent=4, cls=DateTimeEncoder)

print(json_data)
