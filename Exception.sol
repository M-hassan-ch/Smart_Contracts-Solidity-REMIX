// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

contract Test{
    error CustomErrr(string);
    function throwErr() public pure{
        //require(false, "Require Error");
        //assert(false);
        revert CustomErrr("Custom Error");
    }
}
contract Exception{
    event RequireError(string);
    event AssertError(uint);
    event CustomErr(bytes);

    function check() public{
        Test _contract = new Test();

        try _contract.throwErr(){
            //
        }
        catch Error(string memory reason){
            emit RequireError(reason);
        }
        catch Panic(uint code){
            emit AssertError(code);
        }
        catch(bytes memory reason){
            emit CustomErr(reason);
        }
    }
}