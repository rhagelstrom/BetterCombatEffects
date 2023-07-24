--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2023
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
-- For an example of how I use this in practice, see scripts/core/manager_bce.lua
------------------ BINARY SEARCH GUARDED FUNCTIONS------------------
-- These are guarded because people will have a bad day if these are changed
-- With all the effects from 5eAE the processing on the custom effects list is signifigant.
-- Binary search will greatly speed things up O(log n) vs O(n). Worst case will match on a
-- table of 10,000 records on the 13th attemp Only works on a sorted list so you'll have to
-- keep a copy local and keep it updated. Use constructSearch() to safely construct the effect.
-- To search for returns nil on failure or the a tSearch on success minus the sOperation. If
-- searching and multiple effects that have the same name, it will match the first. If
-- multiple names are equal it will secondary order the records based on database path.
-- luacheck: globals BinarySearchManager
local function binarySearchGuarded(tSortedSearch, tSearch, nLowValue, nHighValue)
    if nHighValue < nLowValue then
        if tSearch.sOperation == 'insert' then
            tSearch.sOperation = nil;
            table.insert(tSortedSearch, nLowValue, tSearch);
            tSortedSearch[nLowValue].nPosition = nLowValue;
            return tSortedSearch[nLowValue];
        end
        return nil;
    end

    local nMidValue = math.floor((nLowValue + nHighValue) / 2);
    local tEffect = tSortedSearch[nMidValue];

    if tSearch.sOperation == 'search' then
        if tEffect.sName > tSearch.sName then
            return binarySearchGuarded(tSortedSearch, tSearch, nLowValue, nMidValue - 1);
        elseif tEffect.sName < tSearch.sName then
            return binarySearchGuarded(tSortedSearch, tSearch, nMidValue + 1, nHighValue);
        else
            tSortedSearch[nMidValue].nPosition = nMidValue;
            return tSortedSearch[nMidValue];
        end
    else
        if tEffect.sName > tSearch.sName or ((tEffect.sName == tSearch.sName) and (tEffect.sPath > tSearch.sPath)) then
            return binarySearchGuarded(tSortedSearch, tSearch, nLowValue, nMidValue - 1);
        elseif tEffect.sName < tSearch.sName or (tEffect.sName == tSearch.sName) and (tEffect.sPath < tSearch.sPath) then
            return binarySearchGuarded(tSortedSearch, tSearch, nMidValue + 1, nHighValue);
        else
            if tSearch.sOperation == 'update' then
                tSearch.sOperation = 'insert';
                tSearch.sName = tSearch.sNewName;
                tSearch.sNewName = nil;
                table.remove(tSortedSearch, nMidValue);
                return binarySearchGuarded(tSortedSearch, tSearch, 1, #tSortedSearch);
            elseif tSearch.sOperation == 'remove' then
                tSortedSearch[nMidValue].nPosition = nMidValue;
                local tRet = tSortedSearch[nMidValue];
                table.remove(tSortedSearch, nMidValue);
                return tRet;
            end
        end
    end
end

-- tSearch needs to be constructed as follows
-- tSearch
-- {
--		sName - The parsedEffect label lowered, shortened to the first clause
--		sOperation - "insert" or "remove" or "search" or "update"
--      sPath - The subkey or database node that this record matches to if we are sorting and seraching DB records. This
-- 		allows us to keep a sorted list and of keys and refernce the database node quickly else If sorting non-DB data
--			sPath should be a unique value so just keep a running tally and convert it to a string
--      nPostion - On return, the current position of this record in the in the table being searched. This will change
--			as more records get inserted/deleted
-- }
local function initSearch(sName, sOperation, sPath, sNewName)
    if not sName or not (sOperation == 'insert' or sOperation == 'search' or sOperation == 'remove' or sOperation == 'update') then
        return;
    end
    local tSearch = {sName = sName, sOperation = sOperation, sPath = sPath, nPostition = 0, sNewName = sNewName};
    if not sPath then
        tSearch.sPath = '';
    end
    return tSearch;
end

------------------ END BINARY SEARCH GUARDED FUNCTIONS------------------

--		sName - The parsedEffect label lowered, shortened to the first clause
--		sOperation - "insert" or "remove" or "search" or "update"
--      sPath - The subkey or database node that this record matches to if we are sorting and seraching DB records else
--			If sorting non-DB data you will need unique subkey if sName is the same to avoid collisions
--      nPostion - On return, the position of this record in the in the table being searched
--
--		Keep in mind you can add addtional elements to this if you want them stored/retrieved for quick reference
function constructSearch(sName, sOperation, sPath, sNewName)
    return initSearch(sName, sOperation, sPath, sNewName);
end

-- 		tSortedSearch - table that has been sorted or empty table
--		tSearch - Search datastructure that has been constructed with constructSearch
--		nLowValue - index in the table to sort/search. Usually: 1
--		nHightValue - Highest position in the table to sort/search. Usually: #tSortedSearch

--	Returns tSearch on success with nPosition being the index where this record can be directly accessed.
function binarySearch(tSortedSearch, tSearch, nLowValue, nHighValue)
    return binarySearchGuarded(tSortedSearch, tSearch, nLowValue, nHighValue);
end
