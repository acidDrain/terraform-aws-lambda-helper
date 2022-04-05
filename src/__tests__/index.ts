import { handler } from '../index';
import process from 'process';

const mockEvent = {
  id: "cdc73f9d-aea9-11e3-9d5a-835b769c0d9c",
  'detail-type': "Scheduled Event",
  source: "aws.events",
  account: "123456789012",
  time: "1970-01-01T00:00:00Z",
  region: "us-east-1",
  version: "1.0",
  resources: [
    "arn:aws:events:us-east-1:123456789012:rule/ExampleRule"
  ],
  detail: "Scheduled Event"
}

const mockContext = {
  callbackWaitsForEmptyEventLoop:true,
  functionVersion:"$LATEST",
  functionName:"cron-lambda-dev",
  memoryLimitInMB:"128",
  logGroupName:"/aws/lambda/cron-lambda-dev",
  logStreamName:"2022/04/05/[$LATEST]606bae8daa0c4838bf21b6fe6fae2154",
  invokedFunctionArn:"arn:aws:lambda:us-west-2:689472803903:function:cron-lambda-dev",
  awsRequestId:"e41515b1-3920-4117-8e32-9f0460824844",
  getRemainingTimeInMillis: () => 1000,
  fail: () =>  null,
  done: () => null,
  succeed: () => null
}

describe("handler", () => {
  const lambdaSuccess = {
    body: {
      messages: {},
      content: [""],
      status: 200 
    },
    statusCode: 200
  };

  const lambdaFailure = {
    ...lambdaSuccess,
    body: "Cannot read properties of undefined (reading 'region')",
    statusCode: 500,
  };

  test("it should resolve to a success response object", async () => {
    expect.assertions(1);
    await expect(handler(mockEvent, mockContext)).resolves.toEqual(lambdaSuccess);
  });

  test("it should resolve to a failure object", async () => {
    process.env = undefined;
    expect.assertions(1);
    await expect(handler(mockEvent, mockContext)).resolves.toEqual(lambdaFailure);
  })
})
