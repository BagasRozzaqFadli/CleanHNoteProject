const sdk = require('node-appwrite');

// Inisialisasi client
const client = new sdk.Client();
client
    .setEndpoint('https://fra.cloud.appwrite.io/v1')
    .setProject('cleanhnoteproject')
    .setKey('standard_d8bcc2fec23809899a7e176819334d13efbbfca3a934c9119ab4aac67d02ae97cb902bd68badf2937883924277be10156b136f1e5b4ec9031c0d52834dd70a5421dd83f44e6213cc1fa3e7ec42154a320d49526edaf867474d293854089ece343e706d376be709a67e270ff710f6975813b67b966403471967375e72c7df5401');

const databases = new sdk.Databases(client);

// ID database yang benar
const DATABASE_ID = '6841a248003633f06890';

async function createAttribute(databaseId, collectionId, attr) {
    console.log(`Adding attribute: ${attr.key} (${attr.type}) to collection ${collectionId}`);
    
    try {
        switch (attr.type) {
            case 'string':
                await databases.createStringAttribute(
                    databaseId,
                    collectionId,
                    attr.key,
                    getStringSize(attr.key),
                    attr.required,
                    null,
                    false
                );
                break;
            case 'datetime':
                await databases.createDatetimeAttribute(
                    databaseId,
                    collectionId,
                    attr.key,
                    attr.required,
                    null,
                    false
                );
                break;
            case 'boolean':
                await databases.createBooleanAttribute(
                    databaseId,
                    collectionId,
                    attr.key,
                    attr.required,
                    null
                );
                break;
            case 'integer':
                await databases.createIntegerAttribute(
                    databaseId,
                    collectionId,
                    attr.key,
                    attr.required,
                    null,
                    false,
                    0, // min value
                    10000 // max value (10 ribu)
                );
                break;
            case 'double':
                await databases.createFloatAttribute(
                    databaseId,
                    collectionId,
                    attr.key,
                    attr.required,
                    null,
                    false,
                    0, // min value
                    100000 // max value (100 ribu)
                );
                break;
            default:
                console.warn(`Unsupported attribute type: ${attr.type}`);
        }
        console.log(`Successfully added attribute: ${attr.key}`);
    } catch (error) {
        if (error.code === 409) {
            console.log(`Attribute ${attr.key} already exists, skipping...`);
        } else {
            console.error(`Error creating attribute ${attr.key}:`, error);
            throw error;
        }
    }
}

function getStringSize(key) {
    // Mengurangi ukuran string untuk menghindari attribute_limit_exceeded
    switch (key) {
        case 'email':
            return 100; // Ukuran email yang cukup
        case 'name':
        case 'team_name':
            return 50;
        case 'description':
            return 1000;
        case 'comment':
            return 500;
        case 'message':
            return 200;
        case 'photo_url':
            return 500;
        case 'location_data':
            return 200;
        case 'title':
            return 100;
        case 'status':
            return 20;
        case 'plan_type':
        case 'plan_duration':
            return 20;
        case 'payment_method':
        case 'payment_status':
            return 20;
        case 'photo_type':
            return 20;
        default:
            return 50; // Ukuran default yang lebih kecil
    }
}

async function updateCollections() {
    try {
        console.log('Memulai pembuatan collections...');
        
        const collections = [
            {
                id: 'users',
                name: 'Users',
                attributes: [
                    { key: 'email', type: 'string', required: true },
                    { key: 'name', type: 'string', required: true },
                    { key: 'tenant_id', type: 'string', required: false },
                    { key: 'created_at', type: 'datetime', required: true }
                ]
            },
            {
                id: 'teams',
                name: 'Teams',
                attributes: [
                    { key: 'team_name', type: 'string', required: true },
                    { key: 'leader_id', type: 'string', required: true },
                    { key: 'invitation_code', type: 'string', required: true },
                    { key: 'created_at', type: 'datetime', required: true }
                ]
            },
            {
                id: 'team_members',
                name: 'Team_Members',
                attributes: [
                    { key: 'user_id', type: 'string', required: true },
                    { key: 'team_id', type: 'string', required: true },
                    { key: 'role', type: 'string', required: true },
                    { key: 'joined_at', type: 'datetime', required: true }
                ]
            },
            {
                id: 'tasks',
                name: 'Tasks',
                attributes: [
                    { key: 'title', type: 'string', required: true },
                    { key: 'description', type: 'string', required: true },
                    { key: 'assigned_to', type: 'string', required: true },
                    { key: 'team_id', type: 'string', required: true },
                    { key: 'due_date', type: 'datetime', required: true },
                    { key: 'status', type: 'string', required: true },
                    { key: 'created_at', type: 'datetime', required: true },
                    { key: 'updated_at', type: 'datetime', required: true }
                ]
            },
            {
                id: 'task_comments',
                name: 'Task_Comments',
                attributes: [
                    { key: 'task_id', type: 'string', required: true },
                    { key: 'user_id', type: 'string', required: true },
                    { key: 'comment', type: 'string', required: true },
                    { key: 'created_at', type: 'datetime', required: true }
                ]
            },
            {
                id: 'notifications',
                name: 'Notifications',
                attributes: [
                    { key: 'user_id', type: 'string', required: true },
                    { key: 'message', type: 'string', required: true },
                    { key: 'status', type: 'string', required: true },
                    { key: 'created_at', type: 'datetime', required: true },
                    { key: 'task_id', type: 'string', required: false }
                ]
            },
            {
                id: 'subscriptions',
                name: 'Subscriptions',
                attributes: [
                    { key: 'user_id', type: 'string', required: true },
                    { key: 'plan_type', type: 'string', required: true },
                    { key: 'plan_duration', type: 'string', required: true },
                    { key: 'start_date', type: 'datetime', required: true },
                    { key: 'end_date', type: 'datetime', required: true },
                    { key: 'payment_status', type: 'string', required: true },
                    { key: 'auto_renewal', type: 'boolean', required: true }
                ]
            },
            {
                id: 'payments',
                name: 'Payments',
                attributes: [
                    { key: 'user_id', type: 'string', required: true },
                    { key: 'subscription_id', type: 'string', required: true },
                    { key: 'amount', type: 'string', required: true },
                    { key: 'payment_method', type: 'string', required: true },
                    { key: 'payment_status', type: 'string', required: true },
                    { key: 'transaction_id', type: 'string', required: true },
                    { key: 'payment_proof', type: 'string', required: true }
                ]
            },
            {
                id: 'cleaning_photos',
                name: 'Cleaning_Photos',
                attributes: [
                    { key: 'task_id', type: 'string', required: true },
                    { key: 'user_id', type: 'string', required: true },
                    { key: 'team_id', type: 'string', required: true },
                    { key: 'photo_url', type: 'string', required: true },
                    { key: 'photo_type', type: 'string', required: true },
                    { key: 'location_data', type: 'string', required: true }
                ]
            }
        ];

        for (const collection of collections) {
            console.log(`\nMembuat collection: ${collection.name}`);
            
            try {
                // Buat collection jika belum ada
                try {
                    await databases.createCollection(
                        DATABASE_ID,
                        collection.id,
                        collection.name,
                        ['read("any")', 'write("any")'],
                        true
                    );
                    console.log(`Collection ${collection.name} berhasil dibuat`);
                } catch (error) {
                    if (error.code === 409) {
                        console.log(`Collection ${collection.name} sudah ada, melewati pembuatan...`);
                    } else {
                        console.error(`Error membuat collection ${collection.name}:`, error);
                        throw error;
                    }
                }

                // Tambahkan atribut ke collection
                for (const attr of collection.attributes) {
                    await createAttribute(DATABASE_ID, collection.id, attr);
                    // Tunggu sebentar sebelum membuat atribut berikutnya
                    await new Promise(resolve => setTimeout(resolve, 1000));
                }
            } catch (error) {
                console.error(`Error mengupdate collection ${collection.name}:`, error);
                // Lanjutkan ke collection berikutnya
                continue;
            }

            // Tunggu sebentar sebelum mengupdate collection berikutnya
            await new Promise(resolve => setTimeout(resolve, 2000));
        }

        console.log('\nSemua collections berhasil diupdate!');
    } catch (error) {
        console.error('Error mengupdate collections:', error);
    }
}

updateCollections(); 