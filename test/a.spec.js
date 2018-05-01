const { expect } = require('chai')

describe('suite', function () {
  it('should pass', function () {
    expect(1).to.equal(1)
  })

  it('should also pass', function () {
    expect(1).to.equal(1)
  })

  it('should fail', function () {
    expect(1).to.equal(2)
  })
})