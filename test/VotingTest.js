const {expect} = require("chai");
const {ethers} = require("hardhat");
const {time} = require("@nomicfoundation/hardhat-network-helpers");

const DAY = 24 * 60 * 60;

describe("Voting", function () {
  it("Creating proposal", async function () {
    const [, user,] = await ethers.getSigners();
    const Coin = await (await ethers.getContractFactory("VotingCoin")).deploy();
    const voting = await (await ethers.getContractFactory("Voting")).deploy(Coin.address);
    const id = ethers.BigNumber.from(1);
    await voting.connect(user).getNewProposal(id);
    expect(await voting.ifProposalIsActive(id)).to.true;
  });

  it("Proposal is discarded", async function () {
    const [, user,] = await ethers.getSigners();
    const Coin = await (await ethers.getContractFactory("VotingCoin")).deploy();
    const voting = await (await ethers.getContractFactory("Voting")).deploy(Coin.address);
    const id1 = ethers.BigNumber.from(1);
    const id2 = ethers.BigNumber.from(2);
    const id3 = ethers.BigNumber.from(3);
    const id4 = ethers.BigNumber.from(4);
    await voting.connect(user).getNewProposal(id1);
    await time.increase(DAY);
    await voting.connect(user).getNewProposal(id2);
    await voting.connect(user).getNewProposal(id3);
    await time.increase(2 * DAY);
    expect(await voting.connect(user).getNewProposal(id4)).to.not.reverted;
    expect(await voting.ifProposalIsActive(id1)).to.false;
    expect(await voting.ifProposalIsActive(id2)).to.true;
    expect(await voting.ifProposalIsActive(id3)).to.true;
    expect(await voting.ifProposalIsActive(id4)).to.true;
  });

  it("Proposal is accepted, one user", async function () {
    const [, user,] = await ethers.getSigners();
    const Coin = await (await ethers.getContractFactory("VotingCoin")).deploy();
    const voting = await (await ethers.getContractFactory("Voting")).deploy(Coin.address);
    Coin.transfer(user.address, 55);
    const id = ethers.BigNumber.from(1);
    await voting.connect(user).getNewProposal(id);
    expect(await voting.connect(user).vote(id, true, 55)).to.emit(voting, "Accepted").withArgs(id);
    expect(await voting.ifProposalIsActive(id)).to.false;
  });

  it("Proposal is accepted, two users", async function () {
    const [, firstUser, secondUser] = await ethers.getSigners();
    const Coin = await (await ethers.getContractFactory("VotingCoin")).deploy();
    const voting = await (await ethers.getContractFactory("Voting")).deploy(Coin.address);
    Coin.transfer(firstUser.address, 25);
    Coin.transfer(secondUser.address, 40);
    const id = ethers.BigNumber.from(1);
    await voting.connect(firstUser).getNewProposal(id);
    await voting.connect(firstUser).vote(id, true, 25);
    expect(await voting.ifProposalIsActive(id)).to.true;
    expect(await voting.connect(secondUser).vote(id, true, 40)).to.emit(voting, "Accepted").withArgs(id);
    expect(await voting.ifProposalIsActive(id)).to.false;
  });

  it("Proposal is rejected, two users", async function () {
    const [, firstUser, secondUser] = await ethers.getSigners();
    const Coin = await (await ethers.getContractFactory("VotingCoin")).deploy();
    const voting = await (await ethers.getContractFactory("Voting")).deploy(Coin.address);
    Coin.transfer(firstUser.address, 30);
    Coin.transfer(secondUser.address, 55);
    const id = ethers.BigNumber.from(1);
    await voting.connect(firstUser).getNewProposal(id);
    await voting.connect(firstUser).vote(id, true, 30);
    expect(await voting.ifProposalIsActive(id)).to.true;
    expect(await voting.connect(secondUser).vote(id, false, 55)).to.emit(voting, "Rejected").withArgs(id);
    expect(await voting.ifProposalIsActive(id)).to.false;
  });

  it("One proposal is accepted, another one is rejected", async function () {
    const [, firstUser, secondUser] = await ethers.getSigners();
    const Coin = await (await ethers.getContractFactory("VotingCoin")).deploy();
    const voting = await (await ethers.getContractFactory("Voting")).deploy(Coin.address);
    Coin.transfer(firstUser.address, 30);
    Coin.transfer(secondUser.address, 44);
    const id1 = ethers.BigNumber.from(1);
    const id2 = ethers.BigNumber.from(2);
    await voting.connect(secondUser).getNewProposal(id1);
    await voting.connect(secondUser).getNewProposal(id2);
    await voting.connect(secondUser).vote(id1, true, 44);
    await voting.connect(secondUser).vote(id2, false, 44);
    expect(await voting.connect(firstUser).vote(id2, false, 30)).to.emit(voting, "Rejected").withArgs(id2);
    expect(await voting.connect(firstUser).vote(id1, true, 30)).to.emit(voting, "Accepted").withArgs(id1);
  });
});
