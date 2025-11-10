declare module "papaparse" {
  export interface ParseResult<T> {
    data: T[];
  }

  export interface ParseOptions {
    header?: boolean;
    skipEmptyLines?: boolean | "greedy";
  }

  export function parse<T = unknown>(input: string, options?: ParseOptions): ParseResult<T>;

  const Papa: {
    parse: typeof parse;
  };

  export default Papa;
}
