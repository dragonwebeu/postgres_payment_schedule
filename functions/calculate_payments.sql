CREATE OR REPLACE FUNCTION public.calculate_payments(IN _json_data jsonb,IN component_payment_order integer[],IN _monthly_payment_residue double precision, IN _debug boolean DEFAULT false)
    RETURNS TABLE(row_payment_order jsonb, json_data jsonb, monthly_payment_residue double precision)
    LANGUAGE 'plpgsql'
    
AS $BODY$
DECLARE
pay double precision;
paid double precision;
amount double precision;
variable_name double precision;
row_payment_order JSONB;
BEGIN
row_payment_order := '{}'::JSONB;
json_data := _json_data;
monthly_payment_residue := _monthly_payment_residue;
FOREACH variable_name IN ARRAY component_payment_order
LOOP			
	IF _monthly_payment_residue IS NULL THEN
		RAISE EXCEPTION '_monthly_payment_residue IS NULL';
	END IF;	
	pay := 0;
	paid := 0;
	RAISE NOTICE 'Value: %', variable_name;
	RAISE NOTICE 'amount: %', json_data->variable_name::VARCHAR->>'amount';
	amount := json_data->variable_name::VARCHAR->>'amount';
	IF amount IS NULL THEN
		CONTINUE;
	END IF;
	RAISE NOTICE 'monthly_payment_residue: %', monthly_payment_residue;
	paid := json_data->variable_name::VARCHAR->>'paid';            
	pay := LEAST(amount - paid, monthly_payment_residue);
	RAISE NOTICE 'pay: %', pay;
	paid := paid + pay;
	RAISE NOTICE 'paid: %', paid;
	IF pay > 0 THEN
		json_data := jsonb_set(json_data, concat('{',variable_name,',paid}')::text[], to_jsonb(paid));
		RAISE NOTICE '%', jsonb_set(json_data, concat('{',variable_name,',paid}')::text[], to_jsonb(paid));
		row_payment_order := jsonb_set(row_payment_order, concat('{',variable_name,'}')::text[], to_jsonb(pay));
	END IF;
	RAISE NOTICE 'amount: % , paid: %',amount,paid;
	monthly_payment_residue := monthly_payment_residue-pay;			
END LOOP;
RETURN QUERY SELECT row_payment_order, json_data, monthly_payment_residue;
END;
$BODY$;