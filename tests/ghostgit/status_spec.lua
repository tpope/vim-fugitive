local status = require('ghostgit.status')

describe('ghostgit.status', function()
  it('parses porcelain v2 output correctly', function()
    local lines = {
      "# branch.oid 0123456789abcdef0123456789abcdef01234567",
      "# branch.head main",
      "# branch.upstream origin/main",
      "# branch.ab +0 -0",
      "1 .M N... 100644 100644 100644 0123456789abcdef0123456789abcdef01234567 0123456789abcdef0123456789abcdef01234567 modified.txt",
      "1 M. N... 100644 100644 100644 0123456789abcdef0123456789abcdef01234567 0123456789abcdef0123456789abcdef01234567 staged.txt",
      "? untracked.txt",
    }

    local res = status.parse_porcelain_v2(lines)

    assert.are.equal("main", res.branch)
    assert.are.equal(1, #res.staged)
    assert.are.equal("staged.txt", res.staged[1].filename)
    assert.are.equal("M", res.staged[1].status)

    assert.are.equal(1, #res.unstaged)
    assert.are.equal("modified.txt", res.unstaged[1].filename)
    assert.are.equal("M", res.unstaged[1].status)

    assert.are.equal(1, #res.untracked)
    assert.are.equal("untracked.txt", res.untracked[1].filename)
  end)

  it('handles detached HEAD', function()
    local lines = {
      "# branch.head (detached)",
    }
    local res = status.parse_porcelain_v2(lines)
    assert.are.equal("", res.branch)
  end)
end)
