import { SetStateAction, useEffect, useState } from "react";
import { PositionData } from "../Datatable/types";
import { Environment } from '../env';

export const GetPositions = (accountId:number) => {
	const [positionsData, setPositionsData] = useState<PositionData[]>([]);
	type data = () => Promise<unknown>;
	useEffect(() => {
		let json:SetStateAction<PositionData[]>;
		const fetchData: data = async () => {
			try {
				const response = await fetch(`${Environment.position_service_url}/positions/${accountId}`);
				if (response.ok) {
					json = await response.json();
					setPositionsData(json);
				}
			} catch (error) {
				return error;
			}
		};
		fetchData()
	}, [accountId]);
	return positionsData;
}
