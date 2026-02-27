// Ignore chmod/fchmod failures on filesystems that do not support POSIX mode changes (for example Azure Files SMB).
const fs = require("fs");

const IGNORABLE_CODES = new Set(["EPERM", "ENOTSUP", "EOPNOTSUPP", "EROFS"]);

function ignoreIfUnsupported(err, target) {
  if (err && IGNORABLE_CODES.has(err.code)) {
    const where = target ? ` (${target})` : "";
    process.stderr.write(`[chmod-shim] ignoring ${err.code}${where}\n`);
    return true;
  }
  return false;
}

function wrapCallback(name) {
  const original = fs[name];
  if (typeof original !== "function") return;

  fs[name] = function wrapped(...args) {
    const maybeCb = args[args.length - 1];
    if (typeof maybeCb !== "function") {
      return original.apply(this, args);
    }

    args[args.length - 1] = (err, ...rest) => {
      if (ignoreIfUnsupported(err, args[0])) {
        return maybeCb(null, ...rest);
      }
      return maybeCb(err, ...rest);
    };
    return original.apply(this, args);
  };
}

function wrapSync(name) {
  const original = fs[name];
  if (typeof original !== "function") return;

  fs[name] = function wrapped(...args) {
    try {
      return original.apply(this, args);
    } catch (err) {
      if (ignoreIfUnsupported(err, args[0])) {
        return undefined;
      }
      throw err;
    }
  };
}

function wrapPromise(name) {
  if (!fs.promises || typeof fs.promises[name] !== "function") return;
  const original = fs.promises[name].bind(fs.promises);

  fs.promises[name] = async (...args) => {
    try {
      return await original(...args);
    } catch (err) {
      if (ignoreIfUnsupported(err, args[0])) {
        return undefined;
      }
      throw err;
    }
  };
}

wrapCallback("chmod");
wrapCallback("fchmod");
wrapSync("chmodSync");
wrapSync("fchmodSync");
wrapPromise("chmod");
wrapPromise("fchmod");
