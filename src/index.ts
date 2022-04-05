import * as LambdaResponseBuilder from "./response.js";

interface IBaseENV {
  region: string;
  LambdaName: string;
}

const getValuesFromEnv = (env: NodeJS.ProcessEnv): IBaseENV => ({
  region: env.region,
  LambdaName: env.LambdaName,
});

const returnPayload = { messages: {}, content: [""], status: 200 };

const handler = async (
  event: AWSLambda.EventBridgeEvent<
    "Scheduled Event to Trigger Lambda",
    Record<string, never>
  >,
  context: AWSLambda.Context
): Promise<LambdaResponseBuilder.ILambdaResponse> => {

  try {

  const {
    LambdaName,
    region,
  } = getValuesFromEnv(process.env);

    console.log(`Lambda Name: ${LambdaName}, Lambda Region: ${region}`);
    console.log(`event: ${JSON.stringify(event)}`);
    console.log(`context: ${JSON.stringify(context)}`);
    console.log(JSON.stringify({ message: "OK" }));

    return LambdaResponseBuilder.ReturnSuccess(returnPayload);

  } catch (e) {

    console.log(JSON.stringify({ body: JSON.stringify(e) }));

    return LambdaResponseBuilder.ReturnFailure(e.message);

  }
};

export { handler };

