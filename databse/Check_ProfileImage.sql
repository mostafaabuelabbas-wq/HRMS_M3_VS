-- CHECK SCRIPT: Run this to see what your database thinks 'profile_image' is.

SELECT 
    TABLE_NAME, 
    COLUMN_NAME, 
    DATA_TYPE, 
    CHARACTER_MAXIMUM_LENGTH 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'Employee' AND COLUMN_NAME = 'profile_image';

-- IF functionality is correct, you should see:
-- DATA_TYPE: varbinary
-- CHARACTER_MAXIMUM_LENGTH: -1 (which means MAX)
