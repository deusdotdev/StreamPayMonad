export const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

// streams(id) getter dönüşü:
// [employer, recipient, ratePerMinute, lastClaimTimestamp,
//  employerBalance, lastTopUpTimestamp, active]
export type StreamData = readonly [
  `0x${string}`,
  `0x${string}`,
  bigint,
  bigint,
  bigint,
  bigint,
  boolean,
];
