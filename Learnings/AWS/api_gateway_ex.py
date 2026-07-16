##GET with Query Parameters

# import json
# def lambda_handler(event, context):

#     print("event")
#     print(event)

#     params = event.get("queryStringParameters")
#     print('params')
#     print(params)

#     if params:
#         name = params.get("name", "Guest")
#     else:
#         name = "Guest"

#     return {
#         "statusCode": 200,
#         "body": json.dumps({
#             "message": f"Hello {name}"
#         })
#     }


##GET using Path Parameters

# import json
# def lambda_handler(event, context):

#     path = event.get("pathParameters")
#     print('path')
#     print(path)

#     if path:
#         name = path.get("name")
#         domain = path.get("domain")

#     else:
#         name = "Guest"
#         domain = "Software"

#     return {
#         "statusCode":200,
#         "body":json.dumps({
#             "message":f"I am {name}, {domain} Engineer."
#         })
#     }

## POST using Request Body

# import json
# def lambda_handler(event, context):

#     body = json.loads(event["body"])

#     name = body["name"]
#     age = body["age"]
#     city = body["city"]

#     return {
#         "statusCode":200,
#         "body":json.dumps({
#             "message":"User Created",
#             "user":body
#         })
#     }

## Body + Query Together

import json
def lambda_handler(event, context):

    # Read query parameters
    query_params = event.get("queryStringParameters") or {}
    country = query_params.get("country", "Unknown")

    # Read request body
    body = json.loads(event.get("body", "{}"))

    name = body.get("name")
    age = body.get("age")
    city = body.get("city")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "User Created Successfully",
            "country": country,
            "user": {
                "name": name,
                "age": age,
                "city": city
            }
        })
    }