interface ILambdaResult {
  messages: Record<string, never>;
  content: string[];
  status: number;
}

interface ILambdaResponse {
  statusCode: number;
  body: ILambdaResult;
}

const ReturnSuccess = (body: ILambdaResult) => {
  return buildResponse(200, body);
};

const ReturnFailure = (body: ILambdaResult) => {
  return buildResponse(500, body);
};

const buildResponse = (statusCode: number, body: ILambdaResult): ILambdaResponse => ({
  statusCode: statusCode,
  body,
});

export { ReturnSuccess, ReturnFailure, ILambdaResponse, ILambdaResult };

