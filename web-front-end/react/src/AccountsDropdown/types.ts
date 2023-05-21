import { SelectChangeEvent } from "@mui/material";
import { ReactNode } from "react";

export interface AccountData {
	id: number;
	displayName: string
}

export interface AccountsDropdownProps {
  handleChange: (
    event: SelectChangeEvent<string>, 
    child: ReactNode
    ) => void;
  currentAccount: string;
}

export type MatchingPeople = {
	fullName: string;
}