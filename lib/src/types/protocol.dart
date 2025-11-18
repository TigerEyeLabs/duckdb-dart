/// Supported data protocols for DuckDB
enum DuckDBDataProtocol {
  buffer,
  nodeFs,
  browserFilereader,
  browserFsaccess,
  http,
  s3,
}

/// Protocol constants mapping to DuckDB-WASM values
const duckDBDataProtocolValues = {
  DuckDBDataProtocol.buffer: 0, // BUFFER = 0
  DuckDBDataProtocol.nodeFs: 1, // NODE_FS = 1
  DuckDBDataProtocol.browserFilereader: 2, // BROWSER_FILEREADER = 2
  DuckDBDataProtocol.browserFsaccess: 3, // BROWSER_FSACCESS = 3
  DuckDBDataProtocol.http: 4, // HTTP = 4
  DuckDBDataProtocol.s3: 5, // S3 = 5
};
