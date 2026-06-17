// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medicine_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMedicineEntityCollection on Isar {
  IsarCollection<MedicineEntity> get medicineEntitys => this.collection();
}

const MedicineEntitySchema = CollectionSchema(
  name: r'MedicineEntity',
  id: 8310283481198513094,
  properties: {
    r'alarmId1': PropertySchema(
      id: 0,
      name: r'alarmId1',
      type: IsarType.long,
    ),
    r'alarmId2': PropertySchema(
      id: 1,
      name: r'alarmId2',
      type: IsarType.long,
    ),
    r'alarmId3': PropertySchema(
      id: 2,
      name: r'alarmId3',
      type: IsarType.long,
    ),
    r'counter': PropertySchema(
      id: 3,
      name: r'counter',
      type: IsarType.long,
    ),
    r'createdAt': PropertySchema(
      id: 4,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'customTimes': PropertySchema(
      id: 5,
      name: r'customTimes',
      type: IsarType.stringList,
    ),
    r'dosage': PropertySchema(
      id: 6,
      name: r'dosage',
      type: IsarType.string,
    ),
    r'durationDays': PropertySchema(
      id: 7,
      name: r'durationDays',
      type: IsarType.long,
    ),
    r'everyXDays': PropertySchema(
      id: 8,
      name: r'everyXDays',
      type: IsarType.long,
    ),
    r'frequency': PropertySchema(
      id: 9,
      name: r'frequency',
      type: IsarType.long,
    ),
    r'imagePath': PropertySchema(
      id: 10,
      name: r'imagePath',
      type: IsarType.string,
    ),
    r'isActive': PropertySchema(
      id: 11,
      name: r'isActive',
      type: IsarType.bool,
    ),
    r'isPaused': PropertySchema(
      id: 12,
      name: r'isPaused',
      type: IsarType.bool,
    ),
    r'isTaken': PropertySchema(
      id: 13,
      name: r'isTaken',
      type: IsarType.bool,
    ),
    r'lowStockAlerted': PropertySchema(
      id: 14,
      name: r'lowStockAlerted',
      type: IsarType.bool,
    ),
    r'name': PropertySchema(
      id: 15,
      name: r'name',
      type: IsarType.string,
    ),
    r'notes': PropertySchema(
      id: 16,
      name: r'notes',
      type: IsarType.string,
    ),
    r'qty': PropertySchema(
      id: 17,
      name: r'qty',
      type: IsarType.long,
    ),
    r'scheduleType': PropertySchema(
      id: 18,
      name: r'scheduleType',
      type: IsarType.string,
    ),
    r'slotTypes': PropertySchema(
      id: 19,
      name: r'slotTypes',
      type: IsarType.stringList,
    ),
    r'specificDates': PropertySchema(
      id: 20,
      name: r'specificDates',
      type: IsarType.stringList,
    ),
    r'startDate': PropertySchema(
      id: 21,
      name: r'startDate',
      type: IsarType.dateTime,
    ),
    r'supabaseId': PropertySchema(
      id: 22,
      name: r'supabaseId',
      type: IsarType.string,
    ),
    r'time1': PropertySchema(
      id: 23,
      name: r'time1',
      type: IsarType.string,
    ),
    r'time2': PropertySchema(
      id: 24,
      name: r'time2',
      type: IsarType.string,
    ),
    r'time3': PropertySchema(
      id: 25,
      name: r'time3',
      type: IsarType.string,
    ),
    r'userId': PropertySchema(
      id: 26,
      name: r'userId',
      type: IsarType.string,
    )
  },
  estimateSize: _medicineEntityEstimateSize,
  serialize: _medicineEntitySerialize,
  deserialize: _medicineEntityDeserialize,
  deserializeProp: _medicineEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'supabaseId': IndexSchema(
      id: 2753382765909358918,
      name: r'supabaseId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'supabaseId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _medicineEntityGetId,
  getLinks: _medicineEntityGetLinks,
  attach: _medicineEntityAttach,
  version: '3.1.0+1',
);

int _medicineEntityEstimateSize(
  MedicineEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.customTimes.length * 3;
  {
    for (var i = 0; i < object.customTimes.length; i++) {
      final value = object.customTimes[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.dosage.length * 3;
  {
    final value = object.imagePath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.notes.length * 3;
  bytesCount += 3 + object.scheduleType.length * 3;
  bytesCount += 3 + object.slotTypes.length * 3;
  {
    for (var i = 0; i < object.slotTypes.length; i++) {
      final value = object.slotTypes[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.specificDates.length * 3;
  {
    for (var i = 0; i < object.specificDates.length; i++) {
      final value = object.specificDates[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.supabaseId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.time1;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.time2;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.time3;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.userId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _medicineEntitySerialize(
  MedicineEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.alarmId1);
  writer.writeLong(offsets[1], object.alarmId2);
  writer.writeLong(offsets[2], object.alarmId3);
  writer.writeLong(offsets[3], object.counter);
  writer.writeDateTime(offsets[4], object.createdAt);
  writer.writeStringList(offsets[5], object.customTimes);
  writer.writeString(offsets[6], object.dosage);
  writer.writeLong(offsets[7], object.durationDays);
  writer.writeLong(offsets[8], object.everyXDays);
  writer.writeLong(offsets[9], object.frequency);
  writer.writeString(offsets[10], object.imagePath);
  writer.writeBool(offsets[11], object.isActive);
  writer.writeBool(offsets[12], object.isPaused);
  writer.writeBool(offsets[13], object.isTaken);
  writer.writeBool(offsets[14], object.lowStockAlerted);
  writer.writeString(offsets[15], object.name);
  writer.writeString(offsets[16], object.notes);
  writer.writeLong(offsets[17], object.qty);
  writer.writeString(offsets[18], object.scheduleType);
  writer.writeStringList(offsets[19], object.slotTypes);
  writer.writeStringList(offsets[20], object.specificDates);
  writer.writeDateTime(offsets[21], object.startDate);
  writer.writeString(offsets[22], object.supabaseId);
  writer.writeString(offsets[23], object.time1);
  writer.writeString(offsets[24], object.time2);
  writer.writeString(offsets[25], object.time3);
  writer.writeString(offsets[26], object.userId);
}

MedicineEntity _medicineEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MedicineEntity();
  object.alarmId1 = reader.readLongOrNull(offsets[0]);
  object.alarmId2 = reader.readLongOrNull(offsets[1]);
  object.alarmId3 = reader.readLongOrNull(offsets[2]);
  object.counter = reader.readLong(offsets[3]);
  object.createdAt = reader.readDateTimeOrNull(offsets[4]);
  object.customTimes = reader.readStringList(offsets[5]) ?? [];
  object.dosage = reader.readString(offsets[6]);
  object.durationDays = reader.readLong(offsets[7]);
  object.everyXDays = reader.readLong(offsets[8]);
  object.frequency = reader.readLong(offsets[9]);
  object.id = id;
  object.imagePath = reader.readStringOrNull(offsets[10]);
  object.isActive = reader.readBool(offsets[11]);
  object.isPaused = reader.readBool(offsets[12]);
  object.isTaken = reader.readBool(offsets[13]);
  object.lowStockAlerted = reader.readBool(offsets[14]);
  object.name = reader.readString(offsets[15]);
  object.notes = reader.readString(offsets[16]);
  object.qty = reader.readLong(offsets[17]);
  object.scheduleType = reader.readString(offsets[18]);
  object.slotTypes = reader.readStringList(offsets[19]) ?? [];
  object.specificDates = reader.readStringList(offsets[20]) ?? [];
  object.startDate = reader.readDateTime(offsets[21]);
  object.supabaseId = reader.readStringOrNull(offsets[22]);
  object.time1 = reader.readStringOrNull(offsets[23]);
  object.time2 = reader.readStringOrNull(offsets[24]);
  object.time3 = reader.readStringOrNull(offsets[25]);
  object.userId = reader.readStringOrNull(offsets[26]);
  return object;
}

P _medicineEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset)) as P;
    case 1:
      return (reader.readLongOrNull(offset)) as P;
    case 2:
      return (reader.readLongOrNull(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readStringList(offset) ?? []) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readBool(offset)) as P;
    case 12:
      return (reader.readBool(offset)) as P;
    case 13:
      return (reader.readBool(offset)) as P;
    case 14:
      return (reader.readBool(offset)) as P;
    case 15:
      return (reader.readString(offset)) as P;
    case 16:
      return (reader.readString(offset)) as P;
    case 17:
      return (reader.readLong(offset)) as P;
    case 18:
      return (reader.readString(offset)) as P;
    case 19:
      return (reader.readStringList(offset) ?? []) as P;
    case 20:
      return (reader.readStringList(offset) ?? []) as P;
    case 21:
      return (reader.readDateTime(offset)) as P;
    case 22:
      return (reader.readStringOrNull(offset)) as P;
    case 23:
      return (reader.readStringOrNull(offset)) as P;
    case 24:
      return (reader.readStringOrNull(offset)) as P;
    case 25:
      return (reader.readStringOrNull(offset)) as P;
    case 26:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _medicineEntityGetId(MedicineEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _medicineEntityGetLinks(MedicineEntity object) {
  return [];
}

void _medicineEntityAttach(
    IsarCollection<dynamic> col, Id id, MedicineEntity object) {
  object.id = id;
}

extension MedicineEntityByIndex on IsarCollection<MedicineEntity> {
  Future<MedicineEntity?> getBySupabaseId(String? supabaseId) {
    return getByIndex(r'supabaseId', [supabaseId]);
  }

  MedicineEntity? getBySupabaseIdSync(String? supabaseId) {
    return getByIndexSync(r'supabaseId', [supabaseId]);
  }

  Future<bool> deleteBySupabaseId(String? supabaseId) {
    return deleteByIndex(r'supabaseId', [supabaseId]);
  }

  bool deleteBySupabaseIdSync(String? supabaseId) {
    return deleteByIndexSync(r'supabaseId', [supabaseId]);
  }

  Future<List<MedicineEntity?>> getAllBySupabaseId(
      List<String?> supabaseIdValues) {
    final values = supabaseIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'supabaseId', values);
  }

  List<MedicineEntity?> getAllBySupabaseIdSync(List<String?> supabaseIdValues) {
    final values = supabaseIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'supabaseId', values);
  }

  Future<int> deleteAllBySupabaseId(List<String?> supabaseIdValues) {
    final values = supabaseIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'supabaseId', values);
  }

  int deleteAllBySupabaseIdSync(List<String?> supabaseIdValues) {
    final values = supabaseIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'supabaseId', values);
  }

  Future<Id> putBySupabaseId(MedicineEntity object) {
    return putByIndex(r'supabaseId', object);
  }

  Id putBySupabaseIdSync(MedicineEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'supabaseId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllBySupabaseId(List<MedicineEntity> objects) {
    return putAllByIndex(r'supabaseId', objects);
  }

  List<Id> putAllBySupabaseIdSync(List<MedicineEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'supabaseId', objects, saveLinks: saveLinks);
  }
}

extension MedicineEntityQueryWhereSort
    on QueryBuilder<MedicineEntity, MedicineEntity, QWhere> {
  QueryBuilder<MedicineEntity, MedicineEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension MedicineEntityQueryWhere
    on QueryBuilder<MedicineEntity, MedicineEntity, QWhereClause> {
  QueryBuilder<MedicineEntity, MedicineEntity, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterWhereClause>
      supabaseIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'supabaseId',
        value: [null],
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterWhereClause>
      supabaseIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'supabaseId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterWhereClause>
      supabaseIdEqualTo(String? supabaseId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'supabaseId',
        value: [supabaseId],
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterWhereClause>
      supabaseIdNotEqualTo(String? supabaseId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'supabaseId',
              lower: [],
              upper: [supabaseId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'supabaseId',
              lower: [supabaseId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'supabaseId',
              lower: [supabaseId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'supabaseId',
              lower: [],
              upper: [supabaseId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension MedicineEntityQueryFilter
    on QueryBuilder<MedicineEntity, MedicineEntity, QFilterCondition> {
  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      alarmId1IsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'alarmId1',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      alarmId1IsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'alarmId1',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      alarmId1EqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'alarmId1',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      alarmId1GreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'alarmId1',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      alarmId1LessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'alarmId1',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      alarmId1Between(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'alarmId1',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      alarmId2IsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'alarmId2',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      alarmId2IsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'alarmId2',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      alarmId2EqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'alarmId2',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      alarmId2GreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'alarmId2',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      alarmId2LessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'alarmId2',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      alarmId2Between(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'alarmId2',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      alarmId3IsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'alarmId3',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      alarmId3IsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'alarmId3',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      alarmId3EqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'alarmId3',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      alarmId3GreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'alarmId3',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      alarmId3LessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'alarmId3',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      alarmId3Between(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'alarmId3',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      counterEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'counter',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      counterGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'counter',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      counterLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'counter',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      counterBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'counter',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      createdAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdAt',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      createdAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdAt',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      createdAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      createdAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      createdAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      customTimesElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'customTimes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      customTimesElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'customTimes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      customTimesElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'customTimes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      customTimesElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'customTimes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      customTimesElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'customTimes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      customTimesElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'customTimes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      customTimesElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'customTimes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      customTimesElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'customTimes',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      customTimesElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'customTimes',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      customTimesElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'customTimes',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      customTimesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'customTimes',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      customTimesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'customTimes',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      customTimesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'customTimes',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      customTimesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'customTimes',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      customTimesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'customTimes',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      customTimesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'customTimes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      dosageEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dosage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      dosageGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'dosage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      dosageLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'dosage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      dosageBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'dosage',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      dosageStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'dosage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      dosageEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'dosage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      dosageContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'dosage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      dosageMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'dosage',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      dosageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dosage',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      dosageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'dosage',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      durationDaysEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'durationDays',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      durationDaysGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'durationDays',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      durationDaysLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'durationDays',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      durationDaysBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'durationDays',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      everyXDaysEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'everyXDays',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      everyXDaysGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'everyXDays',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      everyXDaysLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'everyXDays',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      everyXDaysBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'everyXDays',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      frequencyEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'frequency',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      frequencyGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'frequency',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      frequencyLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'frequency',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      frequencyBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'frequency',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      imagePathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'imagePath',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      imagePathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'imagePath',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      imagePathEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      imagePathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'imagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      imagePathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'imagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      imagePathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'imagePath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      imagePathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'imagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      imagePathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'imagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      imagePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'imagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      imagePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'imagePath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      imagePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imagePath',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      imagePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'imagePath',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      isActiveEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isActive',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      isPausedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isPaused',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      isTakenEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isTaken',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      lowStockAlertedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lowStockAlerted',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'name',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      nameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      notesEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      notesGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      notesLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      notesBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'notes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      notesStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      notesEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      notesContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      notesMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'notes',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      notesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notes',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      notesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'notes',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      qtyEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'qty',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      qtyGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'qty',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      qtyLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'qty',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      qtyBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'qty',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      scheduleTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'scheduleType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      scheduleTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'scheduleType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      scheduleTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'scheduleType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      scheduleTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'scheduleType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      scheduleTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'scheduleType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      scheduleTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'scheduleType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      scheduleTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'scheduleType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      scheduleTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'scheduleType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      scheduleTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'scheduleType',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      scheduleTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'scheduleType',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      slotTypesElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'slotTypes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      slotTypesElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'slotTypes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      slotTypesElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'slotTypes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      slotTypesElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'slotTypes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      slotTypesElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'slotTypes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      slotTypesElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'slotTypes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      slotTypesElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'slotTypes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      slotTypesElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'slotTypes',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      slotTypesElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'slotTypes',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      slotTypesElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'slotTypes',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      slotTypesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'slotTypes',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      slotTypesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'slotTypes',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      slotTypesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'slotTypes',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      slotTypesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'slotTypes',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      slotTypesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'slotTypes',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      slotTypesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'slotTypes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      specificDatesElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'specificDates',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      specificDatesElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'specificDates',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      specificDatesElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'specificDates',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      specificDatesElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'specificDates',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      specificDatesElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'specificDates',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      specificDatesElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'specificDates',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      specificDatesElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'specificDates',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      specificDatesElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'specificDates',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      specificDatesElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'specificDates',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      specificDatesElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'specificDates',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      specificDatesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'specificDates',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      specificDatesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'specificDates',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      specificDatesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'specificDates',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      specificDatesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'specificDates',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      specificDatesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'specificDates',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      specificDatesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'specificDates',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      startDateEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'startDate',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      startDateGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'startDate',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      startDateLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'startDate',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      startDateBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'startDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      supabaseIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'supabaseId',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      supabaseIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'supabaseId',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      supabaseIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'supabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      supabaseIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'supabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      supabaseIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'supabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      supabaseIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'supabaseId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      supabaseIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'supabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      supabaseIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'supabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      supabaseIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'supabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      supabaseIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'supabaseId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      supabaseIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'supabaseId',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      supabaseIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'supabaseId',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time1IsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'time1',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time1IsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'time1',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time1EqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'time1',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time1GreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'time1',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time1LessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'time1',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time1Between(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'time1',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time1StartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'time1',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time1EndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'time1',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time1Contains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'time1',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time1Matches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'time1',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time1IsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'time1',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time1IsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'time1',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time2IsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'time2',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time2IsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'time2',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time2EqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'time2',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time2GreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'time2',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time2LessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'time2',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time2Between(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'time2',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time2StartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'time2',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time2EndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'time2',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time2Contains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'time2',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time2Matches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'time2',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time2IsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'time2',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time2IsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'time2',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time3IsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'time3',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time3IsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'time3',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time3EqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'time3',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time3GreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'time3',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time3LessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'time3',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time3Between(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'time3',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time3StartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'time3',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time3EndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'time3',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time3Contains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'time3',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time3Matches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'time3',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time3IsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'time3',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      time3IsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'time3',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      userIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'userId',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      userIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'userId',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      userIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      userIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      userIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      userIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'userId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      userIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      userIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      userIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      userIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'userId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      userIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'userId',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterFilterCondition>
      userIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'userId',
        value: '',
      ));
    });
  }
}

extension MedicineEntityQueryObject
    on QueryBuilder<MedicineEntity, MedicineEntity, QFilterCondition> {}

extension MedicineEntityQueryLinks
    on QueryBuilder<MedicineEntity, MedicineEntity, QFilterCondition> {}

extension MedicineEntityQuerySortBy
    on QueryBuilder<MedicineEntity, MedicineEntity, QSortBy> {
  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByAlarmId1() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alarmId1', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByAlarmId1Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alarmId1', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByAlarmId2() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alarmId2', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByAlarmId2Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alarmId2', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByAlarmId3() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alarmId3', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByAlarmId3Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alarmId3', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByCounter() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counter', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByCounterDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counter', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByDosage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dosage', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByDosageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dosage', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByDurationDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationDays', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByDurationDaysDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationDays', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByEveryXDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'everyXDays', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByEveryXDaysDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'everyXDays', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByFrequency() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'frequency', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByFrequencyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'frequency', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByImagePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePath', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByImagePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePath', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByIsActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByIsPaused() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPaused', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByIsPausedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPaused', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByIsTaken() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isTaken', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByIsTakenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isTaken', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByLowStockAlerted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lowStockAlerted', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByLowStockAlertedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lowStockAlerted', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByQty() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qty', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByQtyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qty', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByScheduleType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scheduleType', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByScheduleTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scheduleType', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByStartDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startDate', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByStartDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startDate', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortBySupabaseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supabaseId', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortBySupabaseIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supabaseId', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByTime1() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'time1', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByTime1Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'time1', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByTime2() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'time2', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByTime2Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'time2', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByTime3() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'time3', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByTime3Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'time3', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> sortByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      sortByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }
}

extension MedicineEntityQuerySortThenBy
    on QueryBuilder<MedicineEntity, MedicineEntity, QSortThenBy> {
  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByAlarmId1() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alarmId1', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByAlarmId1Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alarmId1', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByAlarmId2() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alarmId2', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByAlarmId2Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alarmId2', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByAlarmId3() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alarmId3', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByAlarmId3Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alarmId3', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByCounter() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counter', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByCounterDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counter', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByDosage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dosage', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByDosageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dosage', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByDurationDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationDays', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByDurationDaysDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationDays', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByEveryXDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'everyXDays', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByEveryXDaysDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'everyXDays', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByFrequency() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'frequency', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByFrequencyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'frequency', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByImagePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePath', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByImagePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePath', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByIsActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByIsPaused() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPaused', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByIsPausedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPaused', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByIsTaken() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isTaken', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByIsTakenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isTaken', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByLowStockAlerted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lowStockAlerted', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByLowStockAlertedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lowStockAlerted', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByQty() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qty', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByQtyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qty', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByScheduleType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scheduleType', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByScheduleTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scheduleType', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByStartDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startDate', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByStartDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startDate', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenBySupabaseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supabaseId', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenBySupabaseIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supabaseId', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByTime1() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'time1', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByTime1Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'time1', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByTime2() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'time2', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByTime2Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'time2', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByTime3() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'time3', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByTime3Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'time3', Sort.desc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy> thenByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QAfterSortBy>
      thenByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }
}

extension MedicineEntityQueryWhereDistinct
    on QueryBuilder<MedicineEntity, MedicineEntity, QDistinct> {
  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct> distinctByAlarmId1() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'alarmId1');
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct> distinctByAlarmId2() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'alarmId2');
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct> distinctByAlarmId3() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'alarmId3');
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct> distinctByCounter() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'counter');
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct>
      distinctByCustomTimes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'customTimes');
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct> distinctByDosage(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dosage', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct>
      distinctByDurationDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'durationDays');
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct>
      distinctByEveryXDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'everyXDays');
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct>
      distinctByFrequency() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'frequency');
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct> distinctByImagePath(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'imagePath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct> distinctByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isActive');
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct> distinctByIsPaused() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isPaused');
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct> distinctByIsTaken() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isTaken');
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct>
      distinctByLowStockAlerted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lowStockAlerted');
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct> distinctByNotes(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notes', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct> distinctByQty() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'qty');
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct>
      distinctByScheduleType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'scheduleType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct>
      distinctBySlotTypes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'slotTypes');
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct>
      distinctBySpecificDates() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'specificDates');
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct>
      distinctByStartDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'startDate');
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct> distinctBySupabaseId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'supabaseId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct> distinctByTime1(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'time1', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct> distinctByTime2(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'time2', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct> distinctByTime3(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'time3', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MedicineEntity, MedicineEntity, QDistinct> distinctByUserId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'userId', caseSensitive: caseSensitive);
    });
  }
}

extension MedicineEntityQueryProperty
    on QueryBuilder<MedicineEntity, MedicineEntity, QQueryProperty> {
  QueryBuilder<MedicineEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MedicineEntity, int?, QQueryOperations> alarmId1Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'alarmId1');
    });
  }

  QueryBuilder<MedicineEntity, int?, QQueryOperations> alarmId2Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'alarmId2');
    });
  }

  QueryBuilder<MedicineEntity, int?, QQueryOperations> alarmId3Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'alarmId3');
    });
  }

  QueryBuilder<MedicineEntity, int, QQueryOperations> counterProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'counter');
    });
  }

  QueryBuilder<MedicineEntity, DateTime?, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<MedicineEntity, List<String>, QQueryOperations>
      customTimesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'customTimes');
    });
  }

  QueryBuilder<MedicineEntity, String, QQueryOperations> dosageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dosage');
    });
  }

  QueryBuilder<MedicineEntity, int, QQueryOperations> durationDaysProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'durationDays');
    });
  }

  QueryBuilder<MedicineEntity, int, QQueryOperations> everyXDaysProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'everyXDays');
    });
  }

  QueryBuilder<MedicineEntity, int, QQueryOperations> frequencyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'frequency');
    });
  }

  QueryBuilder<MedicineEntity, String?, QQueryOperations> imagePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imagePath');
    });
  }

  QueryBuilder<MedicineEntity, bool, QQueryOperations> isActiveProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isActive');
    });
  }

  QueryBuilder<MedicineEntity, bool, QQueryOperations> isPausedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isPaused');
    });
  }

  QueryBuilder<MedicineEntity, bool, QQueryOperations> isTakenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isTaken');
    });
  }

  QueryBuilder<MedicineEntity, bool, QQueryOperations>
      lowStockAlertedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lowStockAlerted');
    });
  }

  QueryBuilder<MedicineEntity, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<MedicineEntity, String, QQueryOperations> notesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notes');
    });
  }

  QueryBuilder<MedicineEntity, int, QQueryOperations> qtyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'qty');
    });
  }

  QueryBuilder<MedicineEntity, String, QQueryOperations>
      scheduleTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'scheduleType');
    });
  }

  QueryBuilder<MedicineEntity, List<String>, QQueryOperations>
      slotTypesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'slotTypes');
    });
  }

  QueryBuilder<MedicineEntity, List<String>, QQueryOperations>
      specificDatesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'specificDates');
    });
  }

  QueryBuilder<MedicineEntity, DateTime, QQueryOperations> startDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'startDate');
    });
  }

  QueryBuilder<MedicineEntity, String?, QQueryOperations> supabaseIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'supabaseId');
    });
  }

  QueryBuilder<MedicineEntity, String?, QQueryOperations> time1Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'time1');
    });
  }

  QueryBuilder<MedicineEntity, String?, QQueryOperations> time2Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'time2');
    });
  }

  QueryBuilder<MedicineEntity, String?, QQueryOperations> time3Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'time3');
    });
  }

  QueryBuilder<MedicineEntity, String?, QQueryOperations> userIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'userId');
    });
  }
}
